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
    static let resizeMargin: CGFloat = 3

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

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        dragStrip.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dragStrip)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        container.addSubview(scrollView)

        scrollView.documentView = textView

        let m = Self.resizeMargin
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: m),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: m),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -m),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -m),

            dragStrip.topAnchor.constraint(equalTo: container.topAnchor),
            dragStrip.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dragStrip.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dragStrip.heightAnchor.constraint(equalToConstant: DragStripView.height),

            scrollView.topAnchor.constraint(equalTo: dragStrip.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        } else if dragStrip.convert(dragStrip.bounds, to: self).contains(localPoint) {
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

        let minW = Self.minimumWidth + 2 * Self.resizeMargin
        let minH = Self.minimumHeight + 2 * Self.resizeMargin
        if w < minW {
            if activeResizeEdge.contains(.left) {
                x = initialResizeFrame.maxX - minW
            }
            w = minW
        }
        if h < minH {
            if activeResizeEdge.contains(.bottom) {
                y = initialResizeFrame.maxY - minH
            }
            h = minH
        }

        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Cursor

    private static let horizontalResizeCursor = makeResizeCursor(angle: 0)
    private static let neswResizeCursor = makeResizeCursor(angle: .pi / 4)
    private static let verticalResizeCursor = makeResizeCursor(angle: .pi / 2)
    private static let nwseResizeCursor = makeResizeCursor(angle: -.pi / 4)

    private static func makeResizeCursor(angle: CGFloat) -> NSCursor {
        let cx: CGFloat = 9.5, cy: CGFloat = 9.5
        let cosA = cos(angle), sinA = sin(angle)
        func rotate(_ p: NSPoint) -> NSPoint {
            let dx = p.x - cx, dy = p.y - cy
            return NSPoint(x: cx + dx * cosA - dy * sinA, y: cy + dx * sinA + dy * cosA)
        }

        let t1 = [NSPoint(x: 1.5, y: 9.5), NSPoint(x: 7, y: 12.5), NSPoint(x: 7, y: 6.5)].map(rotate)
        let t2 = [NSPoint(x: 17.5, y: 9.5), NSPoint(x: 12, y: 12.5), NSPoint(x: 12, y: 6.5)].map(rotate)

        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: t1[0]); path.line(to: t1[1]); path.line(to: t1[2]); path.close()
            path.move(to: t2[0]); path.line(to: t2[1]); path.line(to: t2[2]); path.close()
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
        return NSCursor(image: image, hotSpot: NSPoint(x: 10, y: 10))
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
        let visualRect = bounds.insetBy(dx: Self.resizeMargin, dy: Self.resizeMargin)
        Self.backgroundColor.setFill()
        NSBezierPath(roundedRect: visualRect, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
        super.draw(dirtyRect)
    }
}

#endif
