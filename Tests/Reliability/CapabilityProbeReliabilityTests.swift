import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Capability probe reliability and degraded mode (C-2, C-7, C-8)")
struct CapabilityProbeReliabilityTests {
    @Test("status reports degraded mode when yabai is unavailable")
    func statusReportsDegradedMode() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: nil),
            panelSync: InMemoryPanelSync()
        )

        let status = await manager.status()

        #expect(status.mode == .degraded)
        #expect(status.warnings.contains("yabai unavailable"))
        #expect(status.space == nil)
    }
}
