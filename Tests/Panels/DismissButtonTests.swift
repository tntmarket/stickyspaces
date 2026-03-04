import Testing
import Foundation
@testable import StickySpacesApp

#if canImport(AppKit)
import AppKit

@Suite("Dismiss button hover-reveal behavior")
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
