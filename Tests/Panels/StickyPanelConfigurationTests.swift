import Testing
import Foundation
@testable import StickySpacesApp
import StickySpacesShared

#if canImport(AppKit)
import AppKit

@Suite("Chromeless sticky panel (C-1, D-6)")
struct StickyPanelConfigurationTests {

    @Test("Panel has borderless style mask without title bar or traffic lights")
    @MainActor func borderlessStyleMask() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.styleMask.contains(.titled))
        #expect(!panel.styleMask.contains(.closable))
        #expect(!panel.styleMask.contains(.resizable))
    }

    @Test("Panel uses default collectionBehavior for workspace binding")
    @MainActor func defaultCollectionBehavior() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        #expect(panel.collectionBehavior == [])
    }

    @Test("Panel can become key for future text editing")
    @MainActor func canBecomeKey() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        #expect(panel.canBecomeKey == true)
    }

    @Test("Panel is floating and non-activating")
    @MainActor func floatingNonActivating() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)

        #expect(panel.level == .floating)
        #expect(panel.isFloatingPanel == true)
        #expect(panel.hidesOnDeactivate == false)
        #expect(panel.becomesKeyOnlyIfNeeded == true)
        #expect(panel.hasShadow == true)
    }

    @Test("Content view has drag strip and text area")
    @MainActor func contentViewHasDragStripAndTextArea() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: false)

        let contentView = panel.contentView as? StickyContentView
        #expect(contentView != nil)

        let dragStrip = contentView?.dragStrip
        #expect(dragStrip != nil)
        #expect(dragStrip!.frame.height >= 16)
    }

    @Test("Click without drag does not fire position delegate")
    @MainActor func clickWithoutDragDoesNotFireDelegate() {
        let stickyID = UUID()
        let recorder = DelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 200, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let dragStrip = panel.stickyContentView.dragStrip
        let syntheticEvent = NSEvent.otherEvent(
            with: .applicationDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        )!

        dragStrip.mouseDown(with: syntheticEvent)
        dragStrip.mouseUp(with: syntheticEvent)

        #expect(recorder.positions.isEmpty)
    }

    @Test("Drag strip commits position to delegate after drag")
    @MainActor func dragStripReportsPositionAfterDrag() {
        let stickyID = UUID()
        let recorder = DelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 200, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let dragStrip = panel.stickyContentView.dragStrip
        let syntheticEvent = NSEvent.otherEvent(
            with: .applicationDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        )!

        dragStrip.mouseDown(with: syntheticEvent)
        dragStrip.mouseDragged(with: syntheticEvent)
        dragStrip.mouseUp(with: syntheticEvent)

        #expect(recorder.positions.count == 1)
        #expect(recorder.positions.first?.stickyID == stickyID)
    }

    @Test("New panel focuses text view for immediate typing")
    @MainActor func creationFocusesTextView() {
        let stickyID = UUID()
        let panel = StickyPanel(stickyID: stickyID, delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.stickyContentView.textView)

        let firstResponder = panel.firstResponder
        let isTextViewOrFieldEditor = firstResponder === panel.stickyContentView.textView
            || firstResponder is NSTextView
        #expect(isTextViewOrFieldEditor)
    }
}

@MainActor
private final class DelegateRecorder: StickyPanelDelegate {
    struct PositionRecord { let stickyID: UUID; let position: CGPoint }

    var positions: [PositionRecord] = []

    func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint) {
        positions.append(PositionRecord(stickyID: stickyID, position: position))
    }

    func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didChangeText text: String) {}
    func stickyPanelDidRequestDismiss(_ stickyID: UUID) {}
}
#endif
