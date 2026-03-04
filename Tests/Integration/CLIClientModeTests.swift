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
            #expect("\(error)".count > 0)
        }
    }

    @Test("unknown command returns usage help via socket round-trip")
    func unknownCommandReturnsUsageViaSocketRoundTrip() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let output = try await CLIClientRunner.run(
            args: ["nonexistent-command"], socketPath: env.socketPath
        )
        #expect(output.contains("stickyspaces commands:") || output.contains("usage"))
    }
}
