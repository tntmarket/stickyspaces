import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class StickyPanel: NSPanel {
    let stickyID: UUID
    weak var panelDelegate: StickyPanelDelegate?
    let stickyContentView: StickyContentView

    init(stickyID: UUID, delegate: StickyPanelDelegate?) {
        self.stickyID = stickyID
        self.panelDelegate = delegate
        self.stickyContentView = StickyContentView(stickyID: stickyID, delegate: delegate)
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        hasShadow = true
        collectionBehavior = []
        backgroundColor = .clear
        isOpaque = false

        contentView = stickyContentView
    }

    override var canBecomeKey: Bool { true }
}

#endif
