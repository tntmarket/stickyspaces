import Foundation
import StickySpacesShared

#if canImport(AppKit)
import AppKit
#endif

public protocol ZoomOutOverviewPresenting: Sendable {
    func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async
}

public struct NoopZoomOutOverviewPresenter: ZoomOutOverviewPresenting, Sendable {
    public init() {}

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}
}

#if canImport(AppKit)
public actor AppKitZoomOutOverviewPresenter: ZoomOutOverviewPresenting {
    @MainActor private static var controller: ZoomOutOverviewWindowController?

    public init() {}

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        let controller = await MainActor.run { () -> ZoomOutOverviewWindowController in
            if let existing = Self.controller {
                return existing
            }
            let created = ZoomOutOverviewWindowController()
            Self.controller = created
            return created
        }
        await controller.prepare(snapshot: snapshot, heroSticky: heroSticky)
        await controller.animateZoomOut()
    }

    public func hide() async {
        await MainActor.run {
            Self.controller?.hide()
        }
    }
}

@MainActor
private final class ZoomOutOverviewWindowController {
    private let panel: NSPanel
    private let view: ZoomOutOverviewView

    init() {
        let initialFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)

        view = ZoomOutOverviewView(frame: initialFrame)
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
    }

    func prepare(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        let screenFrame = NSScreen.main?.frame ?? panel.frame
        panel.setFrame(screenFrame, display: true)
        view.frame = panel.contentView?.bounds ?? screenFrame
        view.snapshot = snapshot

        let startScale: CGFloat = 1.15
        let startPan = heroAnchoredPan(startScale: startScale, heroSticky: heroSticky, canvasBounds: view.bounds)
        view.displayScale = startScale
        view.panOffset = startPan
        view.transitionProgress = 0
        view.needsDisplay = true

        panel.alphaValue = 1
        panel.orderFrontRegardless()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func animateZoomOut() async {
        let startScale = view.displayScale
        let endScale = max(0.2, CGFloat(view.snapshot.viewport.zoomScale))
        let startPan = view.panOffset
        let endPan = CGPoint(
            x: view.snapshot.viewport.panOffset.x,
            y: view.snapshot.viewport.panOffset.y
        )

        try? await Task.sleep(for: .milliseconds(240))
        let frameCount = 28
        for frame in 0...frameCount {
            let t = CGFloat(frame) / CGFloat(frameCount)
            let eased = t * t * (3 - (2 * t))
            view.displayScale = interpolate(from: startScale, to: endScale, progress: eased)
            view.panOffset = CGPoint(
                x: interpolate(from: startPan.x, to: endPan.x, progress: eased),
                y: interpolate(from: startPan.y, to: endPan.y, progress: eased)
            )
            view.transitionProgress = eased
            view.needsDisplay = true
            try? await Task.sleep(for: .milliseconds(18))
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func heroAnchoredPan(startScale: CGFloat, heroSticky: StickyNote?, canvasBounds: CGRect) -> CGPoint {
        guard let heroSticky else {
            return .zero
        }
        let heroCenter = CGPoint(
            x: heroSticky.position.x + (heroSticky.size.width / 2),
            y: heroSticky.position.y + (heroSticky.size.height / 2)
        )
        let target = CGPoint(x: canvasBounds.midX * 0.42, y: canvasBounds.midY * 0.62)
        return CGPoint(
            x: target.x - (heroCenter.x * startScale),
            y: target.y - (heroCenter.y * startScale)
        )
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + ((to - from) * progress)
    }
}

@MainActor
private final class ZoomOutOverviewView: NSView {
    var snapshot = CanvasSnapshot(
        viewport: .defaultOverview,
        activeWorkspaceID: nil,
        regions: [],
        invariants: []
    )
    var displayScale: CGFloat = 1
    var panOffset: CGPoint = .zero
    var transitionProgress: CGFloat = 1

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 0.98).setFill()
        dirtyRect.fill()

        guard let first = snapshot.regions.first else {
            drawHeader()
            return
        }

        let contentBounds = snapshot.regions.dropFirst().reduce(first.frame) { partial, region in
            partial.union(region.frame)
        }
        let base = centeredBase(contentBounds: contentBounds, scale: displayScale)

        for region in snapshot.regions {
            let transformedFrame = transformed(
                region.frame,
                base: base,
                scale: displayScale,
                panOffset: panOffset
            )
            drawRegion(region, in: transformedFrame)
        }

        drawHeader()
    }

    private func drawHeader() {
        NSString(string: "Zoom-out overview").draw(
            at: CGPoint(x: 24, y: bounds.height - 42),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 0.95)
            ]
        )
    }

    private func drawRegion(_ region: CanvasRegionSnapshot, in frame: CGRect) {
        let path = NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16)
        let fillColor = region.isActive
            ? NSColor(calibratedRed: 0.23, green: 0.44, blue: 0.88, alpha: 0.95)
            : NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 0.92)
        fillColor.setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: frame, xRadius: 16, yRadius: 16)
        let borderColor = region.isActive
            ? NSColor(calibratedRed: 0.74, green: 0.85, blue: 1.0, alpha: 1.0)
            : NSColor(calibratedWhite: 0.52, alpha: 0.9)
        borderColor.setStroke()
        border.lineWidth = region.isActive ? 2.8 : 1.4
        border.stroke()

        let workspaceLabel = "Workspace \(region.workspaceID.rawValue)"
        NSString(string: workspaceLabel).draw(
            at: CGPoint(x: frame.minX + 12, y: frame.maxY - 24),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor(calibratedWhite: 0.95, alpha: 0.95)
            ]
        )

        for preview in region.stickyPreviews.prefix(8) {
            let markerWidth = min(max(12, frame.width * CGFloat(preview.width) * 0.35), frame.width * 0.28)
            let markerHeight = min(max(10, frame.height * CGFloat(preview.height) * 0.35), frame.height * 0.20)
            let markerX = frame.minX + (CGFloat(preview.x) * (frame.width - markerWidth))
            let markerY = frame.minY + (CGFloat(preview.y) * (frame.height - markerHeight))
            let markerRect = CGRect(x: markerX, y: markerY, width: markerWidth, height: markerHeight)

            let marker = NSBezierPath(roundedRect: markerRect, xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.72, alpha: 0.98).setFill()
            marker.fill()
        }
    }

    private func centeredBase(contentBounds: CGRect, scale: CGFloat) -> CGPoint {
        let scaledWidth = contentBounds.width * scale
        let scaledHeight = contentBounds.height * scale
        let x = ((bounds.width - scaledWidth) / 2) - (contentBounds.minX * scale)
        let y = ((bounds.height - scaledHeight) / 2) - (contentBounds.minY * scale)
        return CGPoint(x: x, y: y)
    }

    private func transformed(_ rect: CGRect, base: CGPoint, scale: CGFloat, panOffset: CGPoint) -> CGRect {
        CGRect(
            x: (rect.origin.x * scale) + base.x + panOffset.x,
            y: (rect.origin.y * scale) + base.y + panOffset.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
#else
public actor AppKitZoomOutOverviewPresenter: ZoomOutOverviewPresenting {
    public init() {}

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}

    public func hide() async {}
}
#endif
