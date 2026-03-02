import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

public actor ScreenCaptureKitBackend: CaptureBackend {
    public let kind: CaptureBackendKind = .screenCaptureKit

    private let logger: CaptureLogWriter
    private var stream: SCStream?
    private var request: CaptureStartRequest?
    private var stopReason: CaptureStopReason?
    private var sampleRecorder: StreamSampleRecorder?
    private var recordingOutputToken: AnyObject?
    private var recordingDelegateToken: AnyObject?

    public init(logger: CaptureLogWriter) {
        self.logger = logger
    }

    public func start(request: CaptureStartRequest) async throws {
        if stream != nil {
            throw CaptureError.invalidArgument("screen capture kit backend already started")
        }
        if ScreenRecordingPermissionGate.ensurePermission(requestIfNeeded: request.requestPermissionIfNeeded) != .granted {
            throw CaptureError.permissionDenied
        }

        self.request = request
        try? FileManager.default.removeItem(at: request.outputURL)

        let display = try await resolveDisplay(for: request.displayID)
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )
        let configuration = streamConfiguration(for: display)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        if #available(macOS 15.0, *) {
            let useDirectRecordingOutput = try tryConfigureRecordingOutput(
                stream: stream,
                request: request
            )
            if useDirectRecordingOutput == false {
                try configureAssetWriter(stream: stream, request: request, display: display)
            }
        } else {
            try configureAssetWriter(stream: stream, request: request, display: display)
        }

        do {
            try await stream.startCapture()
        } catch {
            throw CaptureError.captureFailed(reason: "ScreenCaptureKit start failed: \(error)")
        }

        self.stream = stream
        logger.write("[capture] backend=sckit output=\(request.outputURL.path)")
    }

    public func stop(reason: CaptureStopReason) async throws {
        stopReason = reason
        guard let stream else {
            return
        }

        do {
            try await stream.stopCapture()
            if let sampleRecorder {
                try sampleRecorder.finishWritingSync()
            }
            if #available(macOS 15.0, *), recordingOutputToken != nil {
                try await waitForOutputToMaterialize(timeoutSeconds: 3)
            }
        } catch {
            throw CaptureError.captureFailed(reason: "ScreenCaptureKit stop failed: \(error)")
        }
    }

    public func waitUntilFinished() async throws -> CaptureFinishResult {
        guard let request else {
            throw CaptureError.invalidArgument("screen capture kit backend never started")
        }
        if FileManager.default.fileExists(atPath: request.outputURL.path) == false {
            throw CaptureError.outputMissing(request.outputURL)
        }
        let earlyStopped = stopReason == .actionsComplete || stopReason == .teardown
        return CaptureFinishResult(
            outputURL: request.outputURL,
            exitCode: 0,
            earlyStopped: earlyStopped,
            backendKind: kind
        )
    }

    private func resolveDisplay(for requestedDisplayID: Int) async throws -> SCDisplay {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        if let exact = content.displays.first(where: { Int($0.displayID) == requestedDisplayID }) {
            return exact
        }
        if requestedDisplayID > 0 {
            logger.write("[capture] requested display \(requestedDisplayID) unavailable; using first available display")
        }
        guard let first = content.displays.first else {
            throw CaptureError.unavailable(reason: "no shareable displays")
        }
        return first
    }

    private func streamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let bounds = CGDisplayBounds(display.displayID)
        config.width = max(2, Int(bounds.width))
        config.height = max(2, Int(bounds.height))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.capturesAudio = false
        config.showsCursor = true
        config.queueDepth = 6
        return config
    }

    @available(macOS 15.0, *)
    private func tryConfigureRecordingOutput(stream: SCStream, request: CaptureStartRequest) throws -> Bool {
        do {
            let delegate = RecordingOutputDelegateBridge()
            let config = SCRecordingOutputConfiguration()
            config.outputURL = request.outputURL
            config.videoCodecType = .h264
            config.outputFileType = .mov
            let recordingOutput = SCRecordingOutput(configuration: config, delegate: delegate)
            try stream.addRecordingOutput(recordingOutput)
            recordingOutputToken = recordingOutput
            recordingDelegateToken = delegate
            logger.write("[capture] sckit-mode=recording-output")
            return true
        } catch {
            logger.write("[capture] recording-output unavailable, falling back to sample-writer: \(error)")
            return false
        }
    }

    private func configureAssetWriter(
        stream: SCStream,
        request: CaptureStartRequest,
        display: SCDisplay
    ) throws {
        let bounds = CGDisplayBounds(display.displayID)
        let recorder = try StreamSampleRecorder(
            outputURL: request.outputURL,
            width: max(2, Int(bounds.width)),
            height: max(2, Int(bounds.height))
        )
        try stream.addStreamOutput(
            recorder,
            type: .screen,
            sampleHandlerQueue: recorder.sampleQueue
        )
        sampleRecorder = recorder
        logger.write("[capture] sckit-mode=asset-writer")
    }

    private func waitForOutputToMaterialize(timeoutSeconds: Double) async throws {
        guard let outputURL = request?.outputURL else {
            return
        }
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw CaptureError.outputMissing(outputURL)
    }
}

private final class StreamSampleRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let sampleQueue = DispatchQueue(label: "stickyspaces.sckit.sample-writer")

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let lock = NSLock()
    private var startedSession = false
    private var receivedAnySamples = false
    private var finished = false

    init(outputURL: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw CaptureError.captureFailed(reason: "AVAssetWriter cannot add video input")
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw CaptureError.captureFailed(reason: "AVAssetWriter start failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        if finished {
            return
        }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if startedSession == false {
            writer.startSession(atSourceTime: timestamp)
            startedSession = true
        }
        receivedAnySamples = true
        if input.isReadyForMoreMediaData {
            _ = input.append(sampleBuffer)
        }
    }

    func finishWritingSync() throws {
        let didReceiveSamples = finishStateAndReadSampleFlag()
        if didReceiveSamples == nil {
            return
        }
        guard let didReceiveSamples else {
            return
        }

        guard didReceiveSamples else {
            writer.cancelWriting()
            throw CaptureError.captureFailed(reason: "no video samples received from ScreenCaptureKit")
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        let errorBox = ErrorBox()
        writer.finishWriting { [self] in
            if let error = self.writer.error {
                errorBox.error = CaptureError.captureFailed(
                    reason: "AVAssetWriter finish failed: \(error.localizedDescription)"
                )
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let finishError = errorBox.error {
            throw finishError
        }
    }

    private func finishStateAndReadSampleFlag() -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        if finished {
            return nil
        }
        finished = true
        return receivedAnySamples
    }
}

@available(macOS 15.0, *)
private final class RecordingOutputDelegateBridge: NSObject, SCRecordingOutputDelegate {}

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _error: Error?

    var error: Error? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _error
        }
        set {
            lock.lock()
            _error = newValue
            lock.unlock()
        }
    }
}
