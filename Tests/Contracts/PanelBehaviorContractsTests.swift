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

    @Test("Panel views accept first mouse so interactions work when app is not active")
    @MainActor func panelViewsAcceptFirstMouse() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)

        let contentView = panel.stickyContentView
        #expect(contentView.acceptsFirstMouse(for: nil) == true)
        #expect(contentView.dragStrip.acceptsFirstMouse(for: nil) == true)
        #expect(contentView.dragStrip.dismissButton.acceptsFirstMouse(for: nil) == true)
        #expect(contentView.textView.acceptsFirstMouse(for: nil) == true)
    }
}
#endif
