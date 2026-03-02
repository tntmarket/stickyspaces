import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Workspace lifecycle and runtime mode behavior")
struct WorkspaceLifecycleBehaviorTests {
    @Test("Workspace view only shows stickies from that workspace")
    func workspaceViewShowsOnlyItsStickies() async throws {
        let store = StickyStore()
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)

        _ = await store.createSticky(text: "one", workspaceID: workspace1)
        _ = await store.createSticky(text: "two", workspaceID: workspace2)

        let onlyWorkspace1 = await store.list(space: workspace1)

        #expect(onlyWorkspace1.count == 1)
        #expect(onlyWorkspace1[0].workspaceID == workspace1)
        #expect(onlyWorkspace1[0].text == "one")
    }

    @Test("Destroyed workspaces remove their stickies after confirmation")
    func destroyedWorkspaceRemovesItsStickiesAfterConfirmation() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        _ = try await manager.createSticky(text: "A")
        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        _ = try await manager.createSticky(text: "B")

        let initialSnapshot = WorkspaceTopologySnapshot(
            spaces: [
                WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
            ],
            primaryDisplayID: 1
        )
        _ = await manager.reconcileTopology(snapshot: initialSnapshot, health: .healthy, now: Date(timeIntervalSince1970: 0))

        let missingWorkspace1 = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)],
            primaryDisplayID: 1
        )
        _ = await manager.reconcileTopology(snapshot: missingWorkspace1, health: .healthy, now: Date(timeIntervalSince1970: 1))
        _ = await manager.reconcileTopology(snapshot: missingWorkspace1, health: .healthy, now: Date(timeIntervalSince1970: 3))

        #expect(await manager.list(space: workspace1).isEmpty)
        #expect(await manager.list(space: workspace2).count == 1)
    }

    @Test("Rapid workspace switching keeps only the latest topology snapshot")
    func rapidWorkspaceSwitchingKeepsOnlyLatestSnapshot() async throws {
        let monitor = WorkspaceMonitor()
        let s1 = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 1), index: 1, displayID: 1)],
            primaryDisplayID: 1
        )
        let s2 = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 2), index: 2, displayID: 1)],
            primaryDisplayID: 1
        )
        let s3 = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 3), index: 3, displayID: 1)],
            primaryDisplayID: 1
        )

        await monitor.publish(snapshot: s1)
        await monitor.publish(snapshot: s2)
        await monitor.publish(snapshot: s3)

        let drained = await monitor.drainLatest()
        #expect(drained?.spaces.map(\.workspaceID) == [WorkspaceID(rawValue: 3)])
    }

    @Test("Topology reconciler confirms removal before reporting destroyed workspaces")
    func topologyReconcilerConfirmsRemovalBeforeReportingDestroyedWorkspace() async throws {
        let reconciler = WorkspaceTopologyReconciler(confirmationInterval: 2)
        let workspace = WorkspaceID(rawValue: 7)
        let first = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
            primaryDisplayID: 1
        )

        let result1 = await reconciler.reconcile(snapshot: first, health: .healthy, now: Date(timeIntervalSince1970: 0))
        #expect(result1.confirmedRemoved.isEmpty)

        let empty = WorkspaceTopologySnapshot(spaces: [], primaryDisplayID: 1)
        let result2 = await reconciler.reconcile(snapshot: empty, health: .healthy, now: Date(timeIntervalSince1970: 1))
        #expect(result2.confirmedRemoved.isEmpty)

        let result3 = await reconciler.reconcile(snapshot: empty, health: .healthy, now: Date(timeIntervalSince1970: 3))
        #expect(result3.confirmedRemoved == [workspace])
    }

    @Test("First missing snapshot marks workspace as suspected removal")
    func firstMissingSnapshotMarksWorkspaceAsSuspectedRemoval() async throws {
        let reconciler = WorkspaceTopologyReconciler(confirmationInterval: 2)
        let workspace = WorkspaceID(rawValue: 19)
        let present = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
            primaryDisplayID: 1
        )
        let missing = WorkspaceTopologySnapshot(spaces: [], primaryDisplayID: 1)

        _ = await reconciler.reconcile(snapshot: present, health: .healthy, now: Date(timeIntervalSince1970: 0))
        let firstMissing = await reconciler.reconcile(snapshot: missing, health: .healthy, now: Date(timeIntervalSince1970: 1))
        #expect(firstMissing.suspectedRemoved == [workspace])
        #expect(firstMissing.confirmedRemoved.isEmpty)
    }

    @Test("Workspace index renumbering preserves sticky workspace binding")
    func workspaceIndexRenumberingPreservesStickyBinding() async throws {
        let workspace = WorkspaceID(rawValue: 111)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        _ = try await manager.createSticky(text: "bound")

        let indexOne = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
            primaryDisplayID: 1
        )
        _ = await manager.reconcileTopology(snapshot: indexOne, health: .healthy, now: Date(timeIntervalSince1970: 0))

        let indexRenumbered = WorkspaceTopologySnapshot(
            spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 9, displayID: 1)],
            primaryDisplayID: 1
        )
        _ = await manager.reconcileTopology(snapshot: indexRenumbered, health: .healthy, now: Date(timeIntervalSince1970: 1))

        let notes = await manager.list(space: workspace)
        #expect(notes.count == 1)
        #expect(notes[0].text == "bound")
    }

    @Test("Status reports runtime mode and guidance warnings")
    func statusReportsRuntimeModeAndWarnings() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 2), index: 2, displayID: 2)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let status = await manager.status()
        #expect(status.mode == .singleDisplay)
        #expect(status.warnings.contains { $0.contains("single-display") })
        #expect(status.panelVisibilityStrategy == .automaticPrimary)
    }

    @Test("Commands from a non-primary display return unsupported mode")
    func nonPrimaryDisplayCommandsReturnUnsupportedMode() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 2), index: 2, displayID: 2)
                ],
                primaryDisplayID: 1
            )
        )
        await yabai.setCurrentBinding(.stable(workspaceID: WorkspaceID(rawValue: 2), displayID: 2, isPrimaryDisplay: false))

        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let response = try await send(request: .new(text: "should fail"), to: server)
        let details = try unsupportedMode(from: response)
        #expect(details.command == "new")
        #expect(details.mode == .singleDisplay)
        #expect(details.reason.contains("non-primary display"))
    }

    @Test("Status endpoint transitions from normal to single-display to degraded")
    func statusEndpointReportsModeTransitions() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let normal = try statusSnapshot(from: try await send(request: .status, to: server))
        #expect(normal.mode == .normal)

        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: WorkspaceID(rawValue: 3), index: 2, displayID: 2)
                ],
                primaryDisplayID: 1
            )
        )
        let singleDisplay = try statusSnapshot(from: try await send(request: .status, to: server))
        #expect(singleDisplay.mode == .singleDisplay)

        await yabai.setCapabilities(.degraded)
        let degraded = try statusSnapshot(from: try await send(request: .status, to: server))
        #expect(degraded.mode == .degraded)
    }

    private func send(request: IPCRequest, to server: IPCServer) async throws -> IPCResponse {
        let requestLine = try IPCWireCodec.encodeRequestLine(request)
        let responseLine = await server.handleLine(requestLine)
        return try IPCWireCodec.decodeResponseLine(responseLine)
    }

    private func statusSnapshot(from response: IPCResponse) throws -> StatusSnapshot {
        guard case .status(let snapshot) = response else {
            throw UnexpectedIPCResponseError(expected: ".status", actual: response)
        }
        return snapshot
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
