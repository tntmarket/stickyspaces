import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class StickyContentView: NSView {
    static let backgroundColor = NSColor(
        calibratedRed: 1.0, green: 0.98, blue: 0.75, alpha: 1.0
    )
    static let cornerRadius: CGFloat = 8

    let dragStrip: DragStripView
    let textView: NSTextView

    init(stickyID: UUID, delegate: StickyPanelDelegate?) {
        dragStrip = DragStripView(stickyID: stickyID, delegate: delegate)
        textView = NSTextView()
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true

        dragStrip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dragStrip)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        textView.isEditable = true
        textView.isRichText = false
        textView.backgroundColor = Self.backgroundColor
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        NSLayoutConstraint.activate([
            dragStrip.topAnchor.constraint(equalTo: topAnchor),
            dragStrip.leadingAnchor.constraint(equalTo: leadingAnchor),
            dragStrip.trailingAnchor.constraint(equalTo: trailingAnchor),
            dragStrip.heightAnchor.constraint(equalToConstant: DragStripView.height),

            scrollView.topAnchor.constraint(equalTo: dragStrip.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Self.backgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
        super.draw(dirtyRect)
    }
}

#endif
