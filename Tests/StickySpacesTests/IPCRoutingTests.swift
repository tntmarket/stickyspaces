import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesClient
@testable import StickySpacesShared

@Suite("IPC text protocol")
struct IPCRoutingTests {
    @Test("routes new/list over newline-delimited JSON")
    func routesNewListOverTextProtocol() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        _ = try await client.new(text: "One")
        let listed = try await client.list(space: nil)

        #expect(listed.count == 1)
        #expect(listed[0].text == "One")
        #expect(listed[0].workspaceID == WorkspaceID(rawValue: 3))
    }

    @Test("client edit updates sticky text over IPC")
    func clientEditUpdatesStickyTextOverIPC() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        let created = try await client.new(text: "Before")
        try await client.edit(id: created.id, text: "After")
        let listed = try await client.list(space: nil)

        #expect(listed.count == 1)
        #expect(listed[0].text == "After")
    }

    @Test("client move/resize/get round-trips deterministic geometry over IPC")
    func clientMoveResizeGetRoundTripsDeterministicGeometryOverIPC() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        let created = try await client.new(text: "Geom")
        try await client.move(id: created.id, x: 250.5, y: 410.25)
        try await client.resize(id: created.id, width: 300.75, height: 210.5)
        let note = try await client.get(id: created.id)

        #expect(note.position.x == 250.5)
        #expect(note.position.y == 410.25)
        #expect(note.size.width == 300.75)
        #expect(note.size.height == 210.5)
    }
}
