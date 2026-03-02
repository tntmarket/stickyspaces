import Foundation

public protocol CaptureBackend: Sendable {
    var kind: CaptureBackendKind { get }
    func start(request: CaptureStartRequest) async throws
    func stop(reason: CaptureStopReason) async throws
    func waitUntilFinished() async throws -> CaptureFinishResult
}

public protocol CaptureLogWriter: Sendable {
    func write(_ line: String)
}

public struct StdoutCaptureLogger: CaptureLogWriter {
    public init() {}

    public func write(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

public final class InMemoryCaptureLogger: CaptureLogWriter, @unchecked Sendable {
    private let lock = NSLock()
    public private(set) var lines: [String] = []

    public init() {}

    public func write(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }
}
