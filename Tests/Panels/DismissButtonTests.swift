import Testing
import Foundation
@testable import StickySpacesApp

#if canImport(AppKit)
import AppKit

@Suite("Dismiss button hover-reveal behavior (FR-6, FR-DI-5, C-DI-2)")
struct DismissButtonTests {

    @Test("Dismiss button is hidden by default")
    @MainActor func dismissButtonHiddenByDefault() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)

        #expect(panel.stickyContentView.dragStrip.dismissButton.alphaValue == 0)
    }

    @Test("Clicking dismiss button fires delegate callback")
    @MainActor func dismissClickFiresDelegate() {
        let stickyID = UUID()
        let recorder = DismissDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        panel.stickyContentView.dragStrip.dismissButton.performClick(nil)

        #expect(recorder.dismissedIDs == [stickyID])
    }

    @Test("Dismiss button has sufficient hit target size")
    @MainActor func dismissButtonHitTargetSize() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)

        let frame = panel.stickyContentView.dragStrip.dismissButton.frame
        #expect(frame.width >= 20)
        #expect(frame.height >= 20)
    }

    @Test("Mouse enter reveals dismiss button")
    @MainActor func mouseEnterRevealsDismissButton() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        #expect(panel.stickyContentView.dragStrip.dismissButton.alphaValue == 0)

        let enterEvent = NSEvent.otherEvent(
            with: .applicationDefined,
            location: NSPoint(x: 160, y: 110),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil,
            subtype: 0,
            data1: 0,
            data2: 0
        )!
        panel.stickyContentView.mouseEntered(with: enterEvent)

        let button = panel.stickyContentView.dragStrip.dismissButton
        #expect(button.alphaValue == 1.0 || button.animator().alphaValue == 1.0)
    }

    @Test("Dismiss button click in edge zone overlap not intercepted by resize")
    @MainActor func dismissButtonEdgeZoneOverlapNotBlockedByResize() {
        let stickyID = UUID()
        let recorder = DismissDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()
        panel.stickyContentView.layout()

        let contentView = panel.stickyContentView
        let dismissButton = contentView.dragStrip.dismissButton
        dismissButton.alphaValue = 1.0

        let buttonInEdgeZone = contentView.dragStrip.convert(
            NSPoint(x: dismissButton.frame.maxX - 0.5, y: dismissButton.frame.midY),
            to: contentView.superview
        )

        let hitView = contentView.hitTest(buttonInEdgeZone)
        #expect(hitView === dismissButton)
    }

    @Test("Tracking area uses activeAlways for non-key panel hover detection")
    @MainActor func trackingAreaUsesActiveAlways() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.stickyContentView.layout()
        panel.stickyContentView.updateTrackingAreas()

        let hasActiveAlways = panel.stickyContentView.trackingAreas.contains { area in
            area.options.contains(.activeAlways) && area.options.contains(.mouseEnteredAndExited)
        }
        #expect(hasActiveAlways)
    }
}

@MainActor
private final class DismissDelegateRecorder: StickyPanelDelegate {
    var dismissedIDs: [UUID] = []

    func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didChangeText text: String) {}
    func stickyPanelDidRequestDismiss(_ stickyID: UUID) {
        dismissedIDs.append(stickyID)
    }
}
#endif
