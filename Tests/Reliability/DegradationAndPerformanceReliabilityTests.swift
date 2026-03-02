import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Degradation and performance reliability")
struct DegradationAndPerformanceReliabilityTests {
    @Test("focus-space timeout degrades capability while keeping the app responsive")
    func focusSpaceTimeoutDegradesCapabilityWhileKeepingTheAppResponsive() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    .init(workspaceID: workspace1, index: 1, displayID: 1),
                    .init(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        await yabai.setFocusHang(delayMilliseconds: 2_000)

        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync(),
            timeoutPolicy: .init(focusSpaceTimeoutMilliseconds: 25)
        )

        do {
            try await manager.zoomIn(workspaceID: workspace2)
            Issue.record("expected timeout path")
        } catch let error as StickyManagerError {
            switch error {
            case .unsupportedMode(let details):
                #expect(details.reason.contains("timed out"))
            default:
                Issue.record("unexpected error: \(error)")
            }
        }

        let status = await manager.status()
        #expect(status.mode == .degraded)
        #expect(status.warnings.contains { $0.contains("focus-space") })

        _ = try await manager.createSticky(text: "still responsive")
    }

    @Test("nightly performance gate emits a release-blocking signal on regression")
    func nightlyPerformanceGateEmitsReleaseBlockingSignalOnRegression() {
        let failingReport = NightlyPerformanceReport(
            nfr1P95Milliseconds: 130,
            nfr2P95Milliseconds: 510,
            nfr3MemoryMegabytes: 34
        )

        let signal = NightlyPerformanceGate.evaluate(report: failingReport)
        #expect(signal.releaseBlocking)
        #expect(signal.failures.count == 3)
    }
}
