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
    private static let cornerZoneSize: CGFloat = 12

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
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
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
        let cornerZone = Self.cornerZoneSize
        if point.x > bounds.width - cornerZone && point.y < cornerZone {
            return [.right, .bottom]
        }

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
        let edge = resizeEdge(at: localPoint)
        if !edge.isEmpty {
            updateCursor(for: edge)
        } else if dragStrip.frame.contains(localPoint) {
            NSCursor.arrow.set()
        } else {
            NSCursor.iBeam.set()
        }
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

    private static let horizontalResizeCursor = makeResizeCursor(
        tip1: NSPoint(x: 1, y: 8), wing1a: NSPoint(x: 6, y: 11), wing1b: NSPoint(x: 6, y: 5),
        tip2: NSPoint(x: 14, y: 8), wing2a: NSPoint(x: 9, y: 11), wing2b: NSPoint(x: 9, y: 5)
    )
    private static let verticalResizeCursor = makeResizeCursor(
        tip1: NSPoint(x: 8, y: 14), wing1a: NSPoint(x: 5, y: 9), wing1b: NSPoint(x: 11, y: 9),
        tip2: NSPoint(x: 8, y: 1), wing2a: NSPoint(x: 5, y: 6), wing2b: NSPoint(x: 11, y: 6)
    )
    private static let nwseResizeCursor = makeResizeCursor(
        tip1: NSPoint(x: 1, y: 14), wing1a: NSPoint(x: 6, y: 14), wing1b: NSPoint(x: 1, y: 9),
        tip2: NSPoint(x: 14, y: 1), wing2a: NSPoint(x: 9, y: 1), wing2b: NSPoint(x: 14, y: 6)
    )
    private static let neswResizeCursor = makeResizeCursor(
        tip1: NSPoint(x: 14, y: 14), wing1a: NSPoint(x: 9, y: 14), wing1b: NSPoint(x: 14, y: 9),
        tip2: NSPoint(x: 1, y: 1), wing2a: NSPoint(x: 6, y: 1), wing2b: NSPoint(x: 1, y: 6)
    )

    private static func makeResizeCursor(
        tip1: NSPoint, wing1a: NSPoint, wing1b: NSPoint,
        tip2: NSPoint, wing2a: NSPoint, wing2b: NSPoint
    ) -> NSCursor {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: tip1); path.line(to: wing1a); path.line(to: wing1b); path.close()
            path.move(to: tip2); path.line(to: wing2a); path.line(to: wing2b); path.close()
            NSColor.white.setStroke()
            path.lineWidth = 2.5
            path.lineJoinStyle = .round
            path.stroke()
            NSColor.black.setFill()
            path.fill()
            NSColor.black.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }

    private func updateCursor(for edge: ResizeEdge) {
        let isHorizontal = edge.contains(.left) || edge.contains(.right)
        let isVertical = edge.contains(.top) || edge.contains(.bottom)

        if isHorizontal && isVertical {
            let isNWSE = (edge.contains(.left) && edge.contains(.top))
                || (edge.contains(.right) && edge.contains(.bottom))
            (isNWSE ? Self.nwseResizeCursor : Self.neswResizeCursor).set()
        } else if isHorizontal {
            Self.horizontalResizeCursor.set()
        } else if isVertical {
            Self.verticalResizeCursor.set()
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
