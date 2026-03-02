import Foundation

public struct RecordingSessionCoordinator: Sendable {
    public typealias CaptureStarter = @Sendable (CaptureStartRequest) async throws -> CaptureBackend

    private let scenarioID: String
    private let runner: RunnerProcess
    private let captureRequest: CaptureStartRequest
    private let options: RecordingSessionOptions
    private let startCapture: CaptureStarter
    private let logger: CaptureLogWriter
    private let pollIntervalNanoseconds: UInt64

    public init(
        scenarioID: String,
        runner: RunnerProcess,
        captureRequest: CaptureStartRequest,
        options: RecordingSessionOptions,
        startCapture: @escaping CaptureStarter,
        logger: CaptureLogWriter,
        pollIntervalNanoseconds: UInt64 = 100_000_000
    ) {
        self.scenarioID = scenarioID
        self.runner = runner
        self.captureRequest = captureRequest
        self.options = options
        self.startCapture = startCapture
        self.logger = logger
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    public func run() async throws -> RecordingSessionResult {
        let parser = MarkerParser()
        let markers = MarkerTracker()

        try await runner.start { line in
            markers.ingest(line: line, parser: parser, scenarioID: scenarioID, now: Date())
        }

        if options.waitForActionsStart {
            let deadline = Date().addingTimeInterval(options.actionStartTimeoutSeconds)
            while Date() < deadline {
                if markers.startSeen {
                    logger.write("[marker] detected start marker, beginning capture")
                    break
                }
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
            if markers.startSeen == false {
                logger.write("[marker] start marker timeout reached; continuing with fallback timing")
            }
        }

        let captureStartedAt = Date()
        let captureBackend = try await startCapture(captureRequest)
        let captureDeadline = captureStartedAt.addingTimeInterval(captureRequest.maxDurationSeconds)
        var earlyStopped = false

        if options.stopOnActionsComplete {
            while Date() < captureDeadline {
                if markers.completeSeen {
                    if options.tailAfterActionsSeconds > 0 {
                        try await sleep(seconds: options.tailAfterActionsSeconds)
                    }
                    try await captureBackend.stop(reason: .actionsComplete)
                    earlyStopped = true
                    break
                }
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        }

        if earlyStopped == false {
            let remaining = captureDeadline.timeIntervalSinceNow
            if remaining > 0 {
                try await sleep(seconds: remaining)
            }
            try await captureBackend.stop(reason: .maxDuration)
        }

        let captureFinish = try await captureBackend.waitUntilFinished()
        let captureStoppedAt = Date()
        let runnerExitCode = await runner.waitForExit()

        if runnerExitCode != 0 {
            throw CaptureError.runnerFailed(exitCode: runnerExitCode)
        }
        if FileManager.default.fileExists(atPath: captureFinish.outputURL.path) == false {
            throw CaptureError.outputMissing(captureFinish.outputURL)
        }

        return RecordingSessionResult(
            startMarkerSeen: markers.startSeen,
            completeMarkerSeen: markers.completeSeen,
            earlyStopped: earlyStopped,
            captureBackendKind: captureFinish.backendKind,
            captureExitCode: captureFinish.exitCode,
            runnerExitCode: runnerExitCode,
            captureStartedAt: captureStartedAt,
            captureStoppedAt: captureStoppedAt,
            completeMarkerAt: markers.completeMarkerAt,
            outputURL: captureFinish.outputURL
        )
    }

    private func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        if nanoseconds > 0 {
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }
}

private final class MarkerTracker: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startSeen = false
    private(set) var completeSeen = false
    private(set) var completeMarkerAt: Date?

    func ingest(line: String, parser: MarkerParser, scenarioID: String, now: Date) {
        guard let event = parser.parse(line: line), event.scenarioID == scenarioID else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        switch event.kind {
        case .actionsStart:
            startSeen = true
        case .actionsComplete:
            completeSeen = true
            completeMarkerAt = now
        }
    }
}
