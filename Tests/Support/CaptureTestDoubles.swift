import Foundation
@testable import VideoCaptureCore

actor FakeRunnerOutput: RunnerProcess {
    private let lines: [String]
    private let lineDelayNanoseconds: UInt64
    private let exitCode: Int32
    private var waiters: [CheckedContinuation<Int32, Never>] = []
    private var completed = false
    private(set) var completionMarkerDate: Date?

    init(lines: [String], lineDelayNanoseconds: UInt64 = 5_000_000, exitCode: Int32 = 0) {
        self.lines = lines
        self.lineDelayNanoseconds = lineDelayNanoseconds
        self.exitCode = exitCode
    }

    func start(onLine: @escaping @Sendable (String) -> Void) async throws {
        Task {
            let parser = MarkerParser()
            for line in lines {
                onLine(line)
                if parser.parse(line: line)?.kind == .actionsComplete {
                    markCompletionMarkerDate()
                }
                try? await Task.sleep(nanoseconds: lineDelayNanoseconds)
            }
            complete()
        }
    }

    func waitForExit() async -> Int32 {
        if completed {
            return exitCode
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func complete() {
        completed = true
        let pending = waiters
        waiters.removeAll(keepingCapacity: false)
        for waiter in pending {
            waiter.resume(returning: exitCode)
        }
    }

    private func markCompletionMarkerDate() {
        completionMarkerDate = Date()
    }
}

actor FakeCaptureBackend: CaptureBackend {
    let kind: CaptureBackendKind
    private let startError: Error?
    private let finishExitCode: Int32

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var startedOutputURL: URL?
    private(set) var stopTime: Date?
    private var earlyStop = false

    init(kind: CaptureBackendKind, startError: Error? = nil, finishExitCode: Int32 = 0) {
        self.kind = kind
        self.startError = startError
        self.finishExitCode = finishExitCode
    }

    func start(request: CaptureStartRequest) async throws {
        startCount += 1
        if let startError {
            throw startError
        }
        startedOutputURL = request.outputURL
        let dir = request.outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: request.outputURL.path, contents: Data("fake".utf8))
    }

    func stop(reason: CaptureStopReason) async throws {
        stopCount += 1
        stopTime = Date()
        if reason == .actionsComplete {
            earlyStop = true
        }
    }

    func waitUntilFinished() async throws -> CaptureFinishResult {
        guard let startedOutputURL else {
            throw CaptureError.captureFailed(reason: "fake backend not started")
        }
        return CaptureFinishResult(
            outputURL: startedOutputURL,
            exitCode: finishExitCode,
            earlyStopped: earlyStop,
            backendKind: kind
        )
    }
}

func temporaryOutputURL(name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("stickyspaces-tests")
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent(name)
}
