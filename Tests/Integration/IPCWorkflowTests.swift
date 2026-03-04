import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("IPC workflows from a client perspective")
struct IPCWorkflowTests {
    @Test("client creates then lists a sticky over newline-delimited JSON")
    func routesNewListOverTextProtocol() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        _ = try created(from: try await send(request: .new(text: "One"), to: server))
        let listed = try stickyList(from: try await send(request: .list(space: nil), to: server))

        #expect(listed.count == 1)
        #expect(listed[0].text == "One")
        #expect(listed[0].workspaceID == WorkspaceID(rawValue: 3))
    }

    @Test("client edits a sticky and list returns updated text")
    func clientEditUpdatesStickyTextOverIPC() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let created = try created(from: try await send(request: .new(text: "Before"), to: server))
        try expectOK(try await send(request: .edit(id: created.id, text: "After"), to: server))
        let listed = try stickyList(from: try await send(request: .list(space: nil), to: server))

        #expect(listed.count == 1)
        #expect(listed[0].text == "After")
    }

    @Test("client moves and resizes a sticky, then get returns deterministic geometry")
    func clientMoveResizeGetRoundTripsDeterministicGeometryOverIPC() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let created = try created(from: try await send(request: .new(text: "Geom"), to: server))
        try expectOK(try await send(request: .move(id: created.id, x: 250.5, y: 410.25), to: server))
        try expectOK(try await send(request: .resize(id: created.id, width: 300.75, height: 210.5), to: server))
        let note = try sticky(from: try await send(request: .get(id: created.id), to: server))

        #expect(note.position.x == 250.5)
        #expect(note.position.y == 410.25)
        #expect(note.size.width == 300.75)
        #expect(note.size.height == 210.5)
    }

    @Test("dismissing one visible sticky keeps list and panel visibility in sync")
    func multipleVisibleStickiesDismissKeepsVisibilityInSync() async throws {
        let workspace = WorkspaceID(rawValue: 5)
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: panelSync
        )
        let server = IPCServer(manager: manager)
        let first = try created(from: try await send(request: .new(text: "One"), to: server))
        let second = try created(from: try await send(request: .new(text: "Two"), to: server))
        let third = try created(from: try await send(request: .new(text: "Three"), to: server))
        _ = second

        try expectOK(try await send(request: .dismiss(id: first.id), to: server))

        let listed = try stickyList(from: try await send(request: .list(space: workspace), to: server))
        let visible = await panelSync.visibleStickyIDs(on: workspace)

        #expect(listed.count == 2)
        #expect(visible.count == 2)
        #expect(listed.contains(where: { $0.id == first.id }) == false)
        #expect(visible.contains(first.id) == false)
        #expect(visible.contains(third.id))
    }

    @Test("zoom-out snapshot includes sticky previews for the intent panel")
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

        let text = "Ship overview polish\n- verify timing\n- publish demo"
        let created = try created(from: try await send(request: .new(text: text), to: server))
        try expectOK(try await send(request: .move(id: created.id, x: 120, y: 80), to: server))
        let snapshot = try canvasSnapshot(from: try await send(request: .zoomOut, to: server))
        let region = try #require(snapshot.regions.first(where: { $0.workspaceID == workspace }))
        let preview = try #require(region.stickyPreviews.first)

        #expect(preview.id == created.id)
        #expect(preview.text == text)
        #expect(preview.displayHeader == "Ship overview polish")
    }

    @Test("zoom-out returns canvas snapshot over IPC")
    func zoomOutReturnsCanvasSnapshotOverIPC() async throws {
        let workspace1 = WorkspaceID(rawValue: 3)
        let workspace2 = WorkspaceID(rawValue: 8)
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

        _ = try created(from: try await send(request: .new(text: "Overview region"), to: server))
        let snapshot = try canvasSnapshot(from: try await send(request: .zoomOut, to: server))

        #expect(snapshot.activeWorkspaceID == workspace1)
        #expect(snapshot.regions.count == 2)
        #expect(snapshot.regions.contains { $0.workspaceID == workspace1 && $0.stickyCount == 1 })
        #expect(snapshot.regions.contains { $0.workspaceID == workspace2 && $0.stickyCount == 0 })
    }

    @Test("zoom-out reports structured mode warnings")
    func zoomOutReportsStructuredModeWarnings() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setCapabilities(
            CapabilityState(
                canReadCurrentSpace: true,
                canListSpaces: false,
                canFocusSpace: true,
                canDiffTopology: true
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)

        let details = try unsupportedMode(from: try await send(request: .zoomOut, to: server))
        #expect(details.command == "zoom-out")
        #expect(details.mode == .degraded)
        #expect(details.reason.contains("list-spaces"))
        #expect(details.warnings.contains { $0.contains("list-spaces") })
    }

    @Test("clicking a sticky in canvas navigation switches to that sticky workspace")
    func navigateFromCanvasClickSwitchesWorkspace() async throws {
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

        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        let sticky = try created(from: try await send(request: .new(text: "Go here"), to: server))
        await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))

        try expectOK(try await send(request: .navigateFromCanvasClick(stickyID: sticky.id), to: server))
        let status = try statusSnapshot(from: try await send(request: .status, to: server))

        #expect(status.space == workspace2)
        #expect(await yabai.focusedSpaces() == [workspace2])
    }

    private func send(request: IPCRequest, to server: IPCServer) async throws -> IPCResponse {
        let requestLine = try IPCWireCodec.encodeRequestLine(request)
        let responseLine = await server.handleLine(requestLine)
        return try IPCWireCodec.decodeResponseLine(responseLine)
    }

    private func expectOK(_ response: IPCResponse) throws {
        guard case .ok = response else {
            throw UnexpectedIPCResponseError(expected: ".ok", actual: response)
        }
    }

    private func created(from response: IPCResponse) throws -> (id: UUID, workspaceID: WorkspaceID) {
        guard case .created(let id, let workspaceID) = response else {
            throw UnexpectedIPCResponseError(expected: ".created", actual: response)
        }
        return (id: id, workspaceID: workspaceID)
    }

    private func stickyList(from response: IPCResponse) throws -> [StickyNote] {
        guard case .stickyList(let notes) = response else {
            throw UnexpectedIPCResponseError(expected: ".stickyList", actual: response)
        }
        return notes
    }

    private func sticky(from response: IPCResponse) throws -> StickyNote {
        guard case .sticky(let note) = response else {
            throw UnexpectedIPCResponseError(expected: ".sticky", actual: response)
        }
        return note
    }

    private func canvasSnapshot(from response: IPCResponse) throws -> CanvasSnapshot {
        guard case .canvasSnapshot(let snapshot) = response else {
            throw UnexpectedIPCResponseError(expected: ".canvasSnapshot", actual: response)
        }
        return snapshot
    }

    private func statusSnapshot(from response: IPCResponse) throws -> StatusSnapshot {
        guard case .status(let status) = response else {
            throw UnexpectedIPCResponseError(expected: ".status", actual: response)
        }
        return status
    }

    private func unsupportedMode(from response: IPCResponse) throws -> UnsupportedModeResponse {
        guard case .unsupportedMode(let details) = response else {
            throw UnexpectedIPCResponseError(expected: ".unsupportedMode", actual: response)
        }
        return details
    }

    private struct UnexpectedIPCResponseError: Error, CustomStringConvertible {
        let expected: String
        let actual: IPCResponse

        var description: String {
            "expected \(expected), got \(String(describing: actual))"
        }
    }
}
