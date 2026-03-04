import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class DismissButton: NSButton {
    static let size: CGFloat = 20

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = "\u{2715}"
        font = NSFont.systemFont(ofSize: 14)
        isBordered = false
        bezelStyle = .inline
        setButtonType(.momentaryPushIn)
        alphaValue = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

#endif
