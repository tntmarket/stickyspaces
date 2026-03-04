import Testing
import Foundation
@testable import StickySpacesApp

#if canImport(AppKit)
import AppKit

@Suite("Sticky text view debounce behavior")
struct StickyTextViewTests {

    @Test("Text change fires delegate after debounce period")
    @MainActor func textChangeFiresDelegateAfterDebounce() async throws {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let textView = StickyTextView(stickyID: stickyID, delegate: recorder)

        textView.string = "hello"
        textView.didChangeText()

        #expect(recorder.textChanges.isEmpty)

        try await Task.sleep(for: .milliseconds(600))

        #expect(recorder.textChanges.count == 1)
        #expect(recorder.textChanges.first?.text == "hello")
    }

    @Test("Rapid typing resets debounce timer")
    @MainActor func rapidTypingResetsDebounce() async throws {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let textView = StickyTextView(stickyID: stickyID, delegate: recorder)

        textView.string = "h"
        textView.didChangeText()
        try await Task.sleep(for: .milliseconds(200))

        textView.string = "he"
        textView.didChangeText()
        try await Task.sleep(for: .milliseconds(200))

        textView.string = "hel"
        textView.didChangeText()

        #expect(recorder.textChanges.isEmpty)

        try await Task.sleep(for: .milliseconds(600))

        #expect(recorder.textChanges.count == 1)
        #expect(recorder.textChanges.first?.text == "hel")
    }

    @Test("Focus loss flushes pending text immediately")
    @MainActor func flushesOnFocusLoss() async throws {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let textView = StickyTextView(stickyID: stickyID, delegate: recorder)

        textView.string = "draft"
        textView.didChangeText()

        #expect(recorder.textChanges.isEmpty)

        NotificationCenter.default.post(
            name: NSText.didEndEditingNotification,
            object: textView
        )

        #expect(recorder.textChanges.count == 1)
        #expect(recorder.textChanges.first?.text == "draft")
    }

    @Test("Window resign key flushes pending text immediately")
    @MainActor func flushesOnWindowResignKey() {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 0, y: 0, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let textView = panel.stickyContentView.textView
        textView.string = "unsaved draft"
        textView.didChangeText()

        #expect(recorder.textChanges.isEmpty)

        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        #expect(recorder.textChanges.count == 1)
        #expect(recorder.textChanges.first?.text == "unsaved draft")
    }

    @Test("Window resign key from different window does not flush")
    @MainActor func resignKeyFromOtherWindowDoesNotFlush() {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let textView = StickyTextView(stickyID: stickyID, delegate: recorder)

        textView.string = "draft"
        textView.didChangeText()

        NotificationCenter.default.post(
            name: NSWindow.didResignKeyNotification,
            object: NSPanel()
        )

        #expect(recorder.textChanges.isEmpty)
    }

    @Test("Programmatic text set does not trigger delegate")
    @MainActor func programmaticTextSetDoesNotTriggerDelegate() async throws {
        let stickyID = UUID()
        let recorder = TextDelegateRecorder()
        let textView = StickyTextView(stickyID: stickyID, delegate: recorder)

        textView.string = "programmatic update"

        try await Task.sleep(for: .milliseconds(600))

        #expect(recorder.textChanges.isEmpty)
    }
}

@MainActor
private final class TextDelegateRecorder: StickyPanelDelegate {
    struct TextRecord { let stickyID: UUID; let text: String }
    var textChanges: [TextRecord] = []

    func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didChangeText text: String) {
        textChanges.append(TextRecord(stickyID: stickyID, text: text))
    }
    func stickyPanelDidRequestDismiss(_ stickyID: UUID) {}
}
#endif
