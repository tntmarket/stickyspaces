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

    @Test("integration: multiple visible stickies support dismiss and keep visibility in sync")
    func multipleVisibleStickiesDismissKeepsVisibilityInSync() async throws {
        let workspace = WorkspaceID(rawValue: 5)
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: panelSync
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        let first = try await client.new(text: "One")
        let second = try await client.new(text: "Two")
        let third = try await client.new(text: "Three")
        _ = second

        try await client.dismiss(id: first.id)

        let listed = try await client.list(space: workspace)
        let visible = await panelSync.visibleStickyIDs(on: workspace)

        #expect(listed.count == 2)
        #expect(visible.count == 2)
        #expect(listed.contains(where: { $0.id == first.id }) == false)
        #expect(visible.contains(first.id) == false)
        #expect(visible.contains(third.id))
    }

    @Test("zoom-out IPC includes sticky previews for intent panel")
    func zoomOutIncludesStickyPreviewsForIntentPanel() async throws {
        let workspace = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        let text = "Ship FR-7 polish\n- verify timing\n- publish demo"
        let created = try await client.new(text: text)
        try await client.move(id: created.id, x: 120, y: 80)
        let snapshot = try await client.zoomOut()
        let region = try #require(snapshot.regions.first(where: { $0.workspaceID == workspace }))
        let preview = try #require(region.stickyPreviews.first)

        #expect(preview.id == created.id)
        #expect(preview.text == text)
        #expect(preview.displayHeader == "Ship FR-7 polish")
    }

    @Test("test_navigateFromCanvas_clickSticky_switchesWorkspace")
    func test_navigateFromCanvas_clickSticky_switchesWorkspace() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        let sticky = try await client.new(text: "Go here")
        await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))

        try await client.navigateFromCanvasClick(stickyID: sticky.id)
        let status = try await client.status()

        #expect(status.space == workspace2)
        #expect(await yabai.focusedSpaces() == [workspace2])
    }
}
