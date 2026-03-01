import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesClient
@testable import StickySpacesShared

@Suite("Workspace lifecycle and mode handling")
struct WorkspaceLifecycleTests {
    @Test("test_stickiesFilteredByWorkspace")
    func test_stickiesFilteredByWorkspace() async throws {
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

    @Test("test_workspaceDestroyed_deletesAllStickies")
    func test_workspaceDestroyed_deletesAllStickies() async throws {
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

    @Test("test_rapidWorkspaceSwitch_onlyFinalSpaceProcessed")
    func test_rapidWorkspaceSwitch_onlyFinalSpaceProcessed() async throws {
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

    @Test("test_topologyReconciler_singleAuthority_forDestroyedSpaces")
    func test_topologyReconciler_singleAuthority_forDestroyedSpaces() async throws {
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

    @Test("test_topologyReconciler_requiresConfirmedRemoval_beforeDelete")
    func test_topologyReconciler_requiresConfirmedRemoval_beforeDelete() async throws {
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

    @Test("test_workspaceIndexRenumbering_preservesWorkspaceIDBinding")
    func test_workspaceIndexRenumbering_preservesWorkspaceIDBinding() async throws {
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

    @Test("test_statusReportsRuntimeModeAndWarnings")
    func test_statusReportsRuntimeModeAndWarnings() async throws {
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

    @Test("test_nonPrimaryDisplayCommand_returnsUnsupportedMode")
    func test_nonPrimaryDisplayCommand_returnsUnsupportedMode() async throws {
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
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        do {
            _ = try await client.new(text: "should fail")
            Issue.record("expected unsupported mode error")
        } catch let error as StickySpacesClientError {
            switch error {
            case .unsupportedMode(let details):
                #expect(details.command == "new")
                #expect(details.mode == .singleDisplay)
                #expect(details.reason.contains("non-primary display"))
            default:
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    @Test("status endpoint transitions from normal to single-display to degraded")
    func statusEndpoint_reportsModeTransitions() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
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

        let normal = try await client.status()
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
        let singleDisplay = try await client.status()
        #expect(singleDisplay.mode == .singleDisplay)

        await yabai.setCapabilities(.degraded)
        let degraded = try await client.status()
        #expect(degraded.mode == .degraded)
    }
}
