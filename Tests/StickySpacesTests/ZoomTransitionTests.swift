import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Zoom transitions and fallback")
struct ZoomTransitionTests {
    @Test("test_zoomTransition_duration_within300to500ms_p95")
    func test_zoomTransition_duration_within300to500ms_p95() async throws {
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

        var durations: [Int] = []
        for _ in 0..<30 {
            let metrics = try await manager.simulateZoomTransitionRoundTrip(targetWorkspaceID: workspace2)
            durations.append(metrics.durationMilliseconds)
            try await manager.zoomIn(workspaceID: workspace1)
        }

        let sorted = durations.sorted()
        let p95Index = Int(Double(sorted.count - 1) * 0.95)
        let p95 = sorted[p95Index]
        #expect(p95 >= 300)
        #expect(p95 <= 500)
    }

    @Test("test_zoomIn_notificationLoss_recoversWithoutStuckCanvas")
    func test_zoomIn_notificationLoss_recoversWithoutStuckCanvas() async throws {
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
        await yabai.setFocusNotificationLoss(pollsBeforeRecovery: 2)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let metrics = try await manager.simulateZoomTransitionRoundTrip(targetWorkspaceID: workspace2)

        #expect(metrics.usedLivenessFallback)
        #expect(try await yabai.currentSpaceID() == workspace2)
    }

    @Test("test_zoomTransition_modesParity_forced")
    func test_zoomTransition_modesParity_forced() async throws {
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
            panelSync: InMemoryPanelSync(),
            transitionProfile: .init(selectedMode: .continuousBridge, dualModeEnabled: true)
        )

        let parity = try await manager.verifyForcedModeParity(targetWorkspaceID: workspace2)
        #expect(parity.passed)
        #expect(Set(parity.metricsByMode.keys) == Set(ZoomTransitionMode.allCases))
    }
}
