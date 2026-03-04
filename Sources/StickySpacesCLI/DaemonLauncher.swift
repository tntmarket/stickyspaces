import Darwin
import Foundation

public enum DaemonLaunchError: Error, CustomStringConvertible {
    case timeout(logPath: String)
    case spawnFailed(reason: String)

    public var description: String {
        switch self {
        case .timeout(let logPath):
            return "Daemon did not become ready within 3 seconds. Check log: \(logPath)"
        case .spawnFailed(let reason):
            return "Failed to start daemon: \(reason)"
        }
    }
}

public enum DaemonLauncher {
    public static func ensureDaemonRunning(socketPath: String) async throws {
        if probeSocket(at: socketPath) { return }

        try cleanStaleSocket(socketPath: socketPath)
        try spawnDaemon(socketPath: socketPath)
        try await pollUntilReady(socketPath: socketPath)
    }

    private static func probeSocket(at path: String) -> Bool {
        do {
            let client = try IPCSocketClient(socketPath: path)
            client.close()
            return true
        } catch {
            return false
        }
    }

    private static func cleanStaleSocket(socketPath: String) throws {
        guard FileManager.default.fileExists(atPath: socketPath) else { return }

        let lockFD = open(DaemonPaths.lockPath, O_CREAT | O_RDWR, 0o644)
        guard lockFD >= 0 else { return }
        defer { close(lockFD) }

        if flock(lockFD, LOCK_EX | LOCK_NB) == 0 {
            unlink(socketPath)
            flock(lockFD, LOCK_UN)
        }
    }

    private static func spawnDaemon(socketPath: String) throws {
        let executablePath = ProcessInfo.processInfo.arguments[0]
        let logPath = DaemonPaths.configDir + "/daemon.log"

        try FileManager.default.createDirectory(
            atPath: DaemonPaths.configDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        FileManager.default.createFile(atPath: logPath, contents: nil, attributes: nil)

        guard let logHandle = FileHandle(forWritingAtPath: logPath) else {
            throw DaemonLaunchError.spawnFailed(reason: "Cannot open log file at \(logPath)")
        }

        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "STICKYSPACES_SIMULATE_YABAI_UNAVAILABLE")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--daemon"]
        process.environment = env
        process.standardOutput = logHandle
        process.standardError = logHandle

        do {
            try process.run()
        } catch {
            throw DaemonLaunchError.spawnFailed(reason: "\(error)")
        }
    }

    private static func pollUntilReady(socketPath: String) async throws {
        let logPath = DaemonPaths.configDir + "/daemon.log"
        let pollInterval: UInt64 = 50_000_000 // 50ms
        let maxAttempts = 60 // 3 seconds at 50ms intervals

        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: pollInterval)
            if probeSocket(at: socketPath) { return }
        }

        throw DaemonLaunchError.timeout(logPath: logPath)
    }
}
