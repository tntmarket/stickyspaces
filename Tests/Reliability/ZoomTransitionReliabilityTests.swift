import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Zoom transition reliability and fallback (NFR-2, ZO-NFR-1)")
struct ZoomTransitionReliabilityTests {
    @Test("zoom transition p95 duration stays within 300-500 ms")
    func zoomTransitionDurationP95StaysWithinTargetRange() async throws {
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

    @Test("zoom-in recovers from focus-notification loss without a stuck canvas")
    func zoomInNotificationLossRecoversWithoutStuckCanvas() async throws {
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

    @Test("forced mode parity checks pass across transition modes")
    func forcedModeParityChecksPassAcrossTransitionModes() async throws {
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
