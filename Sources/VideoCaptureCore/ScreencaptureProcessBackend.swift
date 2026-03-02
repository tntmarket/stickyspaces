import Foundation

public actor ScreencaptureProcessBackend: CaptureBackend {
    public let kind: CaptureBackendKind = .screencapture

    private let logger: CaptureLogWriter
    private var process: Process?
    private var request: CaptureStartRequest?
    private var exitCode: Int32?
    private var waiters: [CheckedContinuation<Int32, Never>] = []
    private var earlyStopRequested = false

    public init(logger: CaptureLogWriter) {
        self.logger = logger
    }

    public func start(request: CaptureStartRequest) async throws {
        if process != nil {
            throw CaptureError.invalidArgument("screencapture backend already started")
        }
        self.request = request
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        command.arguments = [
            "-x",
            "-D\(request.displayID)",
            "-k",
            "-V\(request.maxDurationSeconds)",
            "-v",
            request.outputURL.path
        ]
        command.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(exitCode: process.terminationStatus)
            }
        }
        do {
            try command.run()
            process = command
            logger.write("[capture] backend=screencapture output=\(request.outputURL.path)")
        } catch {
            throw CaptureError.captureFailed(reason: "screencapture start failed: \(error)")
        }
    }

    public func stop(reason: CaptureStopReason) async throws {
        guard let process else {
            return
        }
        if process.isRunning == false {
            return
        }
        if reason == .actionsComplete || reason == .teardown {
            earlyStopRequested = true
        }
        process.interrupt()
    }

    public func waitUntilFinished() async throws -> CaptureFinishResult {
        guard let request else {
            throw CaptureError.invalidArgument("screencapture backend never started")
        }
        let exit = await waitForExitCode()
        let outputExists = FileManager.default.fileExists(atPath: request.outputURL.path)
        if exit != 0 && !(earlyStopRequested && outputExists) {
            throw CaptureError.captureFailed(reason: "screencapture exited=\(exit)")
        }
        if outputExists == false {
            throw CaptureError.outputMissing(request.outputURL)
        }
        return CaptureFinishResult(
            outputURL: request.outputURL,
            exitCode: exit,
            earlyStopped: earlyStopRequested,
            backendKind: kind
        )
    }

    private func waitForExitCode() async -> Int32 {
        if let exitCode {
            return exitCode
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func handleTermination(exitCode: Int32) {
        self.exitCode = exitCode
        process = nil
        let continuations = waiters
        waiters.removeAll(keepingCapacity: false)
        for continuation in continuations {
            continuation.resume(returning: exitCode)
        }
    }
}
