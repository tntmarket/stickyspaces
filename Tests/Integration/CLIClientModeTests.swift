import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("CLI commands route through socket to a running daemon")
struct CLIClientModeTests {
    @Test("user creates and lists stickies through the client runner")
    func userCreatesAndListsStickiesThroughClientRunner() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let newOutput = try await CLIClientRunner.run(
            args: ["new", "--text", "Sprint planning"], socketPath: env.socketPath
        )
        #expect(newOutput.contains("created"))

        let listOutput = try await CLIClientRunner.run(
            args: ["list"], socketPath: env.socketPath
        )
        #expect(listOutput.contains("Sprint planning"))
    }

    @Test("daemon launcher reuses existing daemon when socket is connectable")
    func daemonLauncherReusesExistingDaemon() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        try await DaemonLauncher.ensureDaemonRunning(socketPath: env.socketPath)
    }

    @Test("CLI prints actionable error when daemon launch fails")
    func cliPrintsActionableErrorWhenLaunchFails() async throws {
        let badPath = "/tmp/nonexistent-\(UUID().uuidString)/test.sock"

        do {
            try await DaemonLauncher.ensureDaemonRunning(socketPath: badPath)
            Issue.record("should have thrown")
        } catch {
            let message = "\(error)"
            #expect(message.contains("not running") || message.contains("daemon"))
        }
    }

    @Test("unknown command returns usage help without contacting daemon")
    func unknownCommandReturnsUsageWithoutContactingDaemon() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let output = try await CLIClientRunner.run(
            args: ["nonexistent-command"], socketPath: env.socketPath
        )
        #expect(output.contains("stickyspaces commands:") || output.contains("usage"))
    }

    @Test("edit and dismiss return informative output with sticky ID")
    func editAndDismissReturnInformativeOutput() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let newOutput = try await CLIClientRunner.run(
            args: ["new", "--text", "Review notes"], socketPath: env.socketPath
        )
        let id = newOutput.components(separatedBy: "id: ")[1].components(separatedBy: " ").first!

        let editOutput = try await CLIClientRunner.run(
            args: ["edit", id, "--text", "Updated notes"], socketPath: env.socketPath
        )
        #expect(editOutput.contains("edited"))
        #expect(editOutput.contains(id))

        let dismissOutput = try await CLIClientRunner.run(
            args: ["dismiss", id], socketPath: env.socketPath
        )
        #expect(dismissOutput.contains("dismissed"))
        #expect(dismissOutput.contains(id))
    }

    @Test("status returns formatted runtime snapshot")
    func statusReturnsFormattedSnapshot() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let output = try await CLIClientRunner.run(
            args: ["status"], socketPath: env.socketPath
        )
        #expect(output.contains("running:"))
        #expect(output.contains("mode:"))
    }
}
