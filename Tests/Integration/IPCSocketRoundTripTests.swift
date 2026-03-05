import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Client connects to daemon via Unix socket and manages stickies (CLI-FR-1, CLI-FR-3, CLI-C-1)")
struct IPCSocketRoundTripTests {
    @Test("client creates a sticky via socket and receives created response with workspace ID")
    func clientCreatesStickyViaSocketAndReceivesCreatedResponse() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let client = try IPCSocketClient(socketPath: env.socketPath)
        let response = try await client.send(.new(text: "Project kickoff notes"))

        guard case .created(_, let workspaceID) = response else {
            Issue.record("expected .created, got \(response)")
            return
        }
        #expect(workspaceID == WorkspaceID(rawValue: 1))
    }

    @Test("state persists across separate client connections to the same server")
    func statePersistsAcrossSeparateClientConnections() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let client1 = try IPCSocketClient(socketPath: env.socketPath)
        let createResponse = try await client1.send(.new(text: "Persistent note"))
        guard case .created = createResponse else {
            Issue.record("expected .created, got \(createResponse)")
            return
        }
        client1.close()

        let client2 = try IPCSocketClient(socketPath: env.socketPath)
        let listResponse = try await client2.send(.list(space: nil))
        guard case .stickyList(let notes) = listResponse else {
            Issue.record("expected .stickyList, got \(listResponse)")
            return
        }
        #expect(notes.count == 1)
        #expect(notes[0].text == "Persistent note")
    }

    @Test("server shutdown removes the socket file from disk")
    func serverShutdownRemovesSocketFile() async throws {
        let env = try await TestServerEnvironment()
        let socketPath = env.socketPath

        #expect(FileManager.default.fileExists(atPath: socketPath))
        await env.shutdown()
        #expect(!FileManager.default.fileExists(atPath: socketPath))
    }

    @Test("socket round-trip completes in under 200ms at p95")
    func socketRoundTripLatencyUnder200ms() async throws {
        let env = try await TestServerEnvironment()
        defer { Task { await env.shutdown() } }

        let clock = ContinuousClock()
        var durations: [Duration] = []

        for _ in 0..<30 {
            let client = try IPCSocketClient(socketPath: env.socketPath)
            let start = clock.now
            _ = try await client.send(.list(space: nil))
            durations.append(clock.now - start)
            client.close()
        }

        durations.sort()
        let p95Index = Int(ceil(Double(durations.count) * 0.95)) - 1
        let p95 = durations[p95Index]
        #expect(p95 < .milliseconds(200), "p95 latency \(p95) exceeds 200ms")
    }
}
