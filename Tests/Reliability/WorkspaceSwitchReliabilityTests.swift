import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Workspace switching reliability (FR-2)")
struct WorkspaceSwitchReliabilityTests {
    @Test("rapid workspace switching converges and each space stays synced")
    func rapidWorkspaceSwitchingConvergesAndEachSpaceStaysSynced() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    .init(workspaceID: workspace1, index: 1, displayID: 1),
                    .init(workspaceID: workspace2, index: 2, displayID: 1),
                    .init(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        for i in 0..<100 {
            let target = [workspace1, workspace2, workspace3][i % 3]
            await yabai.setCurrentBinding(.stable(workspaceID: target, displayID: 1, isPrimaryDisplay: true))
            _ = try await manager.createSticky(text: "stress-\(i)")
        }

        await yabai.setCurrentBinding(.stable(workspaceID: workspace3, displayID: 1, isPrimaryDisplay: true))
        let finalStatus = await manager.status()
        #expect(finalStatus.space == workspace3)

        for space in [workspace1, workspace2, workspace3] {
            let sync = await manager.verifySync(space: space)
            #expect(sync.synced)
        }
    }

    @Test("workspace index renumbering preserves workspace identity binding")
    func workspaceIndexRenumberingPreservesWorkspaceIdentityBinding() async throws {
        let workspace = WorkspaceID(rawValue: 200)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        _ = try await manager.createSticky(text: "bound")

        for i in 1...50 {
            let snapshot = WorkspaceTopologySnapshot(
                spaces: [.init(workspaceID: workspace, index: i, displayID: 1)],
                primaryDisplayID: 1
            )
            _ = await manager.reconcileTopology(snapshot: snapshot, health: .healthy, now: Date(timeIntervalSince1970: TimeInterval(i)))
        }

        let notes = await manager.list(space: workspace)
        #expect(notes.count == 1)
        #expect(notes[0].workspaceID == workspace)
    }

    @Test("health flapping does not delete spaces until absence is stably confirmed")
    func healthFlappingDoesNotDeleteSpacesUntilAbsenceIsStablyConfirmed() async {
        let reconciler = WorkspaceTopologyReconciler(confirmationInterval: 2)
        let workspace = WorkspaceID(rawValue: 9)
        let present = WorkspaceTopologySnapshot(
            spaces: [.init(workspaceID: workspace, index: 1, displayID: 1)],
            primaryDisplayID: 1
        )
        let missing = WorkspaceTopologySnapshot(spaces: [], primaryDisplayID: 1)

        _ = await reconciler.reconcile(snapshot: present, health: .healthy, now: Date(timeIntervalSince1970: 0))
        _ = await reconciler.reconcile(snapshot: missing, health: .unhealthy, now: Date(timeIntervalSince1970: 1))
        let unhealthyResult = await reconciler.reconcile(snapshot: missing, health: .unhealthy, now: Date(timeIntervalSince1970: 3))
        #expect(unhealthyResult.confirmedRemoved.isEmpty)

        let healthyMissing1 = await reconciler.reconcile(snapshot: missing, health: .healthy, now: Date(timeIntervalSince1970: 4))
        #expect(healthyMissing1.confirmedRemoved.isEmpty)

        let healthyMissing2 = await reconciler.reconcile(snapshot: missing, health: .healthy, now: Date(timeIntervalSince1970: 7))
        #expect(healthyMissing2.confirmedRemoved == [workspace])
    }
}
