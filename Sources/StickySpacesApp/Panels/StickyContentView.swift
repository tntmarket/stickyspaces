import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class StickyContentView: NSView {
    static let backgroundColor = NSColor(
        calibratedRed: 1.0, green: 0.98, blue: 0.75, alpha: 1.0
    )
    static let cornerRadius: CGFloat = 8
    static let minimumWidth: CGFloat = 120
    static let minimumHeight: CGFloat = 80

    private static let edgeZoneWidth: CGFloat = 5

    let dragStrip: DragStripView
    let textView: StickyTextView
    private let stickyID: UUID
    private weak var delegate: StickyPanelDelegate?

    private var activeResizeEdge: ResizeEdge = []
    private var initialResizeFrame: NSRect = .zero
    private var initialResizeMouseScreen: NSPoint = .zero

    init(stickyID: UUID, delegate: StickyPanelDelegate?) {
        self.stickyID = stickyID
        self.delegate = delegate
        dragStrip = DragStripView(stickyID: stickyID, delegate: delegate)
        textView = StickyTextView(stickyID: stickyID, delegate: delegate)
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Resize Edge Detection

    private struct ResizeEdge: OptionSet {
        let rawValue: Int
        static let left = ResizeEdge(rawValue: 1 << 0)
        static let right = ResizeEdge(rawValue: 1 << 1)
        static let top = ResizeEdge(rawValue: 1 << 2)
        static let bottom = ResizeEdge(rawValue: 1 << 3)
    }

    private func resizeEdge(at point: NSPoint) -> ResizeEdge {
        let zone = Self.edgeZoneWidth
        var edge: ResizeEdge = []
        if point.x < zone { edge.insert(.left) }
        if point.x > bounds.width - zone { edge.insert(.right) }
        if point.y > bounds.height - zone { edge.insert(.top) }
        if point.y < zone { edge.insert(.bottom) }
        return edge
    }

    // MARK: - Hit Testing

    // Not unit-tested: integration concern for AppKit event dispatch.
    // Ensures edge-zone clicks reach StickyContentView rather than subviews.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        let dismissButtonFrame = dragStrip.convert(dragStrip.dismissButton.frame, to: self)
        if dragStrip.dismissButton.alphaValue > 0 && dismissButtonFrame.contains(localPoint) {
            return dragStrip.dismissButton
        }
        if bounds.contains(localPoint) && !resizeEdge(at: localPoint).isEmpty {
            return self
        }
        return super.hitTest(point)
    }

    // MARK: - Tracking Areas

    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = hoverTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            dragStrip.dismissButton.animator().alphaValue = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            dragStrip.dismissButton.animator().alphaValue = 0
        }
        if activeResizeEdge.isEmpty {
            NSCursor.arrow.set()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        updateCursor(for: resizeEdge(at: localPoint))
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let edge = resizeEdge(at: localPoint)
        guard !edge.isEmpty else {
            super.mouseDown(with: event)
            return
        }
        activeResizeEdge = edge
        initialResizeFrame = window?.frame ?? .zero
        initialResizeMouseScreen = window?.convertPoint(toScreen: event.locationInWindow)
            ?? event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard !activeResizeEdge.isEmpty, let window = window else {
            super.mouseDragged(with: event)
            return
        }
        let currentScreen = window.convertPoint(toScreen: event.locationInWindow)
        let dx = currentScreen.x - initialResizeMouseScreen.x
        let dy = currentScreen.y - initialResizeMouseScreen.y
        window.setFrame(computeResizedFrame(dx: dx, dy: dy), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard !activeResizeEdge.isEmpty else {
            super.mouseUp(with: event)
            return
        }
        activeResizeEdge = []
        guard let frame = window?.frame else { return }
        delegate?.stickyPanel(stickyID, didResizeTo: frame.size, position: frame.origin)
    }

    // MARK: - Resize Computation

    private func computeResizedFrame(dx: CGFloat, dy: CGFloat) -> NSRect {
        var x = initialResizeFrame.origin.x
        var y = initialResizeFrame.origin.y
        var w = initialResizeFrame.width
        var h = initialResizeFrame.height

        if activeResizeEdge.contains(.right) {
            w = initialResizeFrame.width + dx
        }
        if activeResizeEdge.contains(.left) {
            w = initialResizeFrame.width - dx
            x = initialResizeFrame.origin.x + dx
        }
        if activeResizeEdge.contains(.top) {
            h = initialResizeFrame.height + dy
        }
        if activeResizeEdge.contains(.bottom) {
            h = initialResizeFrame.height - dy
            y = initialResizeFrame.origin.y + dy
        }

        if w < Self.minimumWidth {
            if activeResizeEdge.contains(.left) {
                x = initialResizeFrame.maxX - Self.minimumWidth
            }
            w = Self.minimumWidth
        }
        if h < Self.minimumHeight {
            if activeResizeEdge.contains(.bottom) {
                y = initialResizeFrame.maxY - Self.minimumHeight
            }
            h = Self.minimumHeight
        }

        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Cursor

    private func updateCursor(for edge: ResizeEdge) {
        let isHorizontal = edge.contains(.left) || edge.contains(.right)
        let isVertical = edge.contains(.top) || edge.contains(.bottom)

        if isHorizontal && isVertical {
            NSCursor.crosshair.set()
        } else if isHorizontal {
            NSCursor.resizeLeftRight.set()
        } else if isVertical {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        Self.backgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
        super.draw(dirtyRect)
    }
}

#endif
