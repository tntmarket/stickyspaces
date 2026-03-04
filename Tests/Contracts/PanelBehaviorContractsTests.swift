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
        let sticky = StickyNote(text: "Focus context", workspaceID: WorkspaceID(rawValue: 3))
        let registry = AppKitPanelRegistry()
        let panel = registry.makePanel(sticky: sticky)

        #expect(panel.hidesOnDeactivate == false)
    }

    @Test("Sticky panel floats above application windows without activating")
    @MainActor func stickyPanelFloatsWithoutActivating() {
        let sticky = StickyNote(text: "Stay on top", workspaceID: WorkspaceID(rawValue: 5))
        let registry = AppKitPanelRegistry()
        let panel = registry.makePanel(sticky: sticky)

        #expect(panel.isFloatingPanel == true)
        #expect(panel.level == .floating)
        #expect(panel.becomesKeyOnlyIfNeeded == true)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }
}
#endif
