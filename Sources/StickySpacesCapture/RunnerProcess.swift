import Foundation

public protocol RunnerProcess: Sendable {
    func start(onLine: @escaping @Sendable (String) -> Void) async throws
    func waitForExit() async -> Int32
}

public struct RunnerCommand: Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let logFileURL: URL?

    public init(executableURL: URL, arguments: [String], logFileURL: URL?) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.logFileURL = logFileURL
    }
}

public actor ProcessRunner: RunnerProcess {
    private let command: RunnerCommand
    private var process: Process?
    private var exitWaiters: [CheckedContinuation<Int32, Never>] = []
    private var lineBuffer = Data()
    private var logHandle: FileHandle?
    private var exitCode: Int32?

    public init(command: RunnerCommand) {
        self.command = command
    }

    public func start(onLine: @escaping @Sendable (String) -> Void) async throws {
        if process != nil {
            throw CaptureError.invalidArgument("runner already started")
        }

        if let logFileURL = command.logFileURL {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            logHandle = try FileHandle(forWritingTo: logFileURL)
        }

        let task = Process()
        let outputPipe = Pipe()
        task.executableURL = command.executableURL
        task.arguments = command.arguments
        task.standardOutput = outputPipe
        task.standardError = outputPipe
        task.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(exitCode: process.terminationStatus)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.isEmpty == false else {
                Task { await self?.flushLineBuffer(onLine: onLine) }
                return
            }
            Task { await self?.handleOutputChunk(data, onLine: onLine) }
        }

        do {
            try task.run()
            process = task
        } catch {
            throw CaptureError.captureFailed(reason: "failed to launch runner: \(error)")
        }
    }

    public func waitForExit() async -> Int32 {
        if let exitCode {
            return exitCode
        }
        return await withCheckedContinuation { continuation in
            exitWaiters.append(continuation)
        }
    }

    private func handleTermination(exitCode: Int32) {
        self.exitCode = exitCode
        process = nil
        closeLogHandle()
        let waiters = exitWaiters
        exitWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume(returning: exitCode)
        }
    }

    private func handleOutputChunk(_ chunk: Data, onLine: @escaping @Sendable (String) -> Void) {
        lineBuffer.append(chunk)
        while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer.prefix(upTo: newlineIndex)
            lineBuffer.removeSubrange(...newlineIndex)
            guard let line = String(data: lineData, encoding: .utf8) else {
                continue
            }
            emitLine(line, onLine: onLine)
        }
    }

    private func flushLineBuffer(onLine: @escaping @Sendable (String) -> Void) {
        guard lineBuffer.isEmpty == false else {
            return
        }
        let data = lineBuffer
        lineBuffer.removeAll(keepingCapacity: false)
        if let line = String(data: data, encoding: .utf8) {
            emitLine(line, onLine: onLine)
        }
    }

    private func emitLine(_ line: String, onLine: @escaping @Sendable (String) -> Void) {
        onLine(line)
        logHandle?.write(Data((line + "\n").utf8))
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }

    private func closeLogHandle() {
        guard let logHandle else {
            return
        }
        try? logHandle.synchronize()
        try? logHandle.close()
        self.logHandle = nil
    }
}
