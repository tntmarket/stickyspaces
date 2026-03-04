import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

#if canImport(AppKit)
import AppKit

@Suite("Panel behavior contracts (C-1: floating, non-activating, always visible)")
struct PanelBehaviorContractsTests {
    @Test("Sticky panel stays visible when app deactivates")
    @MainActor func stickyPanelStaysVisibleWhenAppDeactivates() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        #expect(panel.hidesOnDeactivate == false)
    }

    @Test("Sticky panel floats above application windows without activating")
    @MainActor func stickyPanelFloatsWithoutActivating() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)

        #expect(panel.isFloatingPanel == true)
        #expect(panel.level == .floating)
        #expect(panel.becomesKeyOnlyIfNeeded == true)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }
}
#endif
