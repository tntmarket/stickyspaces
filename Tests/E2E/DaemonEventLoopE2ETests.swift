import Foundation
import Testing

@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Daemon event loop processes IPC commands that require @MainActor", .serialized)
struct DaemonEventLoopE2ETests {

    @Test("CLI create command receives response from daemon within timeout")
    func cliCreateReceivesResponse() async throws {
        let binary = try binaryPath()
        try killExistingDaemon()

        let daemon = try startDaemon(binary: binary)
        defer {
            daemon.terminate()
            daemon.waitUntilExit()
            cleanupSocketFiles()
        }
        try await waitForSocket(timeout: .seconds(3))

        let (output, exitCode) = try await runCLIWithExitCode(
            binary: binary,
            args: ["new", "--text", "Event loop E2E"],
            timeout: .seconds(5)
        )

        #expect(exitCode == 0, "CLI exited with code \(exitCode)")
        #expect(output.contains("created"), "Expected daemon response, got: \(output)")
    }

    @Test("CLI mode exits cleanly after command completes")
    func cliModeExitsCleanly() async throws {
        let binary = try binaryPath()
        try killExistingDaemon()

        let daemon = try startDaemon(binary: binary)
        defer {
            daemon.terminate()
            daemon.waitUntilExit()
            cleanupSocketFiles()
        }
        try await waitForSocket(timeout: .seconds(3))

        let (output, exitCode) = try await runCLIWithExitCode(
            binary: binary,
            args: ["list"],
            timeout: .seconds(5)
        )

        #expect(exitCode == 0, "CLI should exit cleanly, got code \(exitCode). Output: \(output)")
    }
}

private func binaryPath() throws -> String {
    let testFile = #filePath
    let repoRoot = URL(fileURLWithPath: testFile)
        .deletingLastPathComponent() // E2E/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // repo root
        .path
    let path = repoRoot + "/.build/debug/stickyspaces"
    guard FileManager.default.fileExists(atPath: path) else {
        throw BinaryNotFound(path: path)
    }
    return path
}

private struct BinaryNotFound: Error, CustomStringConvertible {
    let path: String
    var description: String { "Binary not found at \(path) — run `swift build` first" }
}

private func startDaemon(binary: String) throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = ["--daemon"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    return process
}

private func waitForSocket(timeout: Duration) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if let client = try? IPCSocketClient(socketPath: DaemonPaths.socketPath) {
            client.close()
            return
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw SocketTimeout()
}

private struct SocketTimeout: Error, CustomStringConvertible {
    var description: String { "Daemon socket did not become connectable within timeout" }
}

private func runCLI(binary: String, args: [String], timeout: Duration) async throws -> String {
    let (output, _) = try await runCLIWithExitCode(binary: binary, args: args, timeout: timeout)
    return output
}

private func runCLIWithExitCode(
    binary: String, args: [String], timeout: Duration
) async throws -> (output: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binary)
    process.arguments = args
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    try process.run()

    let result: (output: String, exitCode: Int32) = try await withThrowingTaskGroup(
        of: (String, Int32).self
    ) { group in
        group.addTask {
            process.waitUntilExit()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            var output = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            if !stderr.isEmpty { output += " [stderr: \(stderr)]" }
            return (output, process.terminationStatus)
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            if process.isRunning { process.terminate() }
            throw CLITimeout(args: args, timeout: timeout)
        }
        let value = try await group.next()!
        group.cancelAll()
        return value
    }
    return result
}

private struct CLITimeout: Error, CustomStringConvertible {
    let args: [String]
    let timeout: Duration
    var description: String {
        "CLI process \(args) did not exit within \(timeout) — possible @MainActor deadlock"
    }
}

private func killExistingDaemon() throws {
    let socketPath = DaemonPaths.socketPath
    guard let probe = try? IPCSocketClient(socketPath: socketPath) else { return }
    probe.close()

    let pgrep = Process()
    pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    pgrep.arguments = ["-f", "stickyspaces --daemon"]
    let pipe = Pipe()
    pgrep.standardOutput = pipe
    pgrep.standardError = FileHandle.nullDevice
    try? pgrep.run()
    pgrep.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let pidOutput = String(data: data, encoding: .utf8) ?? ""
    for line in pidOutput.split(separator: "\n") {
        if let pid = pid_t(line.trimmingCharacters(in: .whitespaces)), pid > 0 {
            kill(pid, SIGTERM)
        }
    }

    Thread.sleep(forTimeInterval: 0.5)
    cleanupSocketFiles()
}

private func cleanupSocketFiles() {
    setDaemonCleanupPaths(socket: DaemonPaths.socketPath, lock: DaemonPaths.lockPath)
    performDaemonCleanup()
}
