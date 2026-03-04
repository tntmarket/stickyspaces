import CoreGraphics
import Foundation
import StickySpacesShared

#if canImport(AppKit)
import AppKit
#endif

public protocol DesktopCaptureProviding: Sendable {
    func captureMainDisplay() -> CGImage?
}

public struct NoopDesktopCapture: DesktopCaptureProviding, Sendable {
    public init() {}

    public func captureMainDisplay() -> CGImage? { nil }
}

public struct BackgroundCaptureResult: Sendable, Equatable {
    public let source: CanvasThumbnailSource
    public let capturedAt: Date?

    public init(source: CanvasThumbnailSource, capturedAt: Date? = nil) {
        self.source = source
        self.capturedAt = capturedAt
    }

    public static func from(capturedImage: CGImage?, now: Date = Date()) -> BackgroundCaptureResult {
        guard capturedImage != nil else {
            return BackgroundCaptureResult(source: .synthetic)
        }
        return BackgroundCaptureResult(source: .liveCapture, capturedAt: now)
    }
}

public protocol ZoomOutOverviewPresenting: Sendable {
    func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async
    func preparePresentation(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async
    func animatePreparedPresentation() async
}

public extension ZoomOutOverviewPresenting {
    func preparePresentation(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        await present(snapshot: snapshot, heroSticky: heroSticky)
    }

    func animatePreparedPresentation() async {}
}

public struct NoopZoomOutOverviewPresenter: ZoomOutOverviewPresenting, Sendable {
    public init() {}

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}

    public func preparePresentation(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}

    public func animatePreparedPresentation() async {}
}

public struct ZoomOutAnimationMetrics: Sendable, Equatable {
    public let durationMilliseconds: Int
    public let frameCount: Int
    public let heroSampleCount: Int
    public let maxHeroAnchorStepPoints: Double?

    public init(
        durationMilliseconds: Int,
        frameCount: Int,
        heroSampleCount: Int,
        maxHeroAnchorStepPoints: Double?
    ) {
        self.durationMilliseconds = durationMilliseconds
        self.frameCount = frameCount
        self.heroSampleCount = heroSampleCount
        self.maxHeroAnchorStepPoints = maxHeroAnchorStepPoints
    }
}

#if canImport(AppKit)
public struct CGDisplayDesktopCapture: DesktopCaptureProviding, Sendable {
    public init() {}

    public func captureMainDisplay() -> CGImage? {
        CGDisplayCreateImage(CGMainDisplayID())
    }
}

public actor AppKitZoomOutOverviewPresenter: ZoomOutOverviewPresenting {
    @MainActor private static var controller: ZoomOutOverviewWindowController?
    private let captureProvider: any DesktopCaptureProviding
    private var lastAnimationMetrics: ZoomOutAnimationMetrics?
    private var lastBackgroundCaptureResult: BackgroundCaptureResult?

    public init(captureProvider: any DesktopCaptureProviding = CGDisplayDesktopCapture()) {
        self.captureProvider = captureProvider
    }

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        await preparePresentation(snapshot: snapshot, heroSticky: heroSticky)
        await animatePreparedPresentation()
    }

    public func preparePresentation(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        let controller = await resolveController()
        lastBackgroundCaptureResult = await controller.prepare(snapshot: snapshot, heroSticky: heroSticky)
    }

    public func animatePreparedPresentation() async {
        let controller = await resolveController()
        lastAnimationMetrics = await controller.animateZoomOut()
    }

    public func latestAnimationMetrics() async -> ZoomOutAnimationMetrics? {
        lastAnimationMetrics
    }

    public func backgroundCaptureResult() -> BackgroundCaptureResult? {
        lastBackgroundCaptureResult
    }

    public func hide() async {
        await MainActor.run {
            Self.controller?.hide()
        }
    }

    @MainActor
    private func resolveController() -> ZoomOutOverviewWindowController {
        if let existing = Self.controller {
            return existing
        }
        let created = ZoomOutOverviewWindowController(captureProvider: captureProvider)
        Self.controller = created
        return created
    }
}

@MainActor
private final class ZoomOutOverviewWindowController {
    private let panel: NSPanel
    private let view: ZoomOutOverviewView
    private let captureProvider: any DesktopCaptureProviding
    private var preparedHeroSticky: StickyNote?

    init(captureProvider: any DesktopCaptureProviding) {
        self.captureProvider = captureProvider
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

    @discardableResult
    func prepare(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async -> BackgroundCaptureResult {
        let screenFrame = NSScreen.main?.frame ?? panel.frame
        panel.setFrame(screenFrame, display: true)
        panel.orderOut(nil)
        view.frame = panel.contentView?.bounds ?? screenFrame
        view.snapshot = snapshot

        let capturedImage = captureProvider.captureMainDisplay()
        view.backgroundSnapshotImage = capturedImage
        let captureResult = BackgroundCaptureResult.from(capturedImage: capturedImage)

        preparedHeroSticky = heroSticky

        let startScale: CGFloat = 1.15
        let startPan = heroAnchoredPan(startScale: startScale, heroSticky: heroSticky, canvasBounds: view.bounds)
        view.displayScale = startScale
        view.panOffset = startPan
        view.transitionProgress = 0
        view.needsDisplay = true

        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.contentView?.displayIfNeeded()
        panel.displayIfNeeded()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return captureResult
    }

    func animateZoomOut() async -> ZoomOutAnimationMetrics {
        let startScale = view.displayScale
        let endScale = max(0.2, CGFloat(view.snapshot.viewport.zoomScale))
        let startPan = view.panOffset
        let endPan = CGPoint(
            x: view.snapshot.viewport.panOffset.x,
            y: view.snapshot.viewport.panOffset.y
        )
        let heroAnchorCanvasPoint = resolveHeroAnchorCanvasPoint(
            heroSticky: preparedHeroSticky,
            snapshot: view.snapshot
        )
        let startedAt = Date()
        var previousHeroPoint: CGPoint?
        var maxHeroAnchorStep: CGFloat = 0
        var heroSampleCount = 0
        let frameCount = 24
        let frameIntervalMilliseconds = 16

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

            if let heroAnchorCanvasPoint,
               let heroPoint = view.screenPoint(forCanvasPoint: heroAnchorCanvasPoint) {
                heroSampleCount += 1
                if let previousHeroPoint {
                    maxHeroAnchorStep = max(
                        maxHeroAnchorStep,
                        hypot(
                            heroPoint.x - previousHeroPoint.x,
                            heroPoint.y - previousHeroPoint.y
                        )
                    )
                }
                previousHeroPoint = heroPoint
            }
            if frame < frameCount {
                try? await Task.sleep(for: .milliseconds(frameIntervalMilliseconds))
            }
        }

        let durationMilliseconds = Int((Date().timeIntervalSince(startedAt) * 1000).rounded())
        return ZoomOutAnimationMetrics(
            durationMilliseconds: durationMilliseconds,
            frameCount: frameCount + 1,
            heroSampleCount: heroSampleCount,
            maxHeroAnchorStepPoints: heroSampleCount > 1 ? Double(maxHeroAnchorStep) : nil
        )
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

    private func resolveHeroAnchorCanvasPoint(
        heroSticky: StickyNote?,
        snapshot: CanvasSnapshot
    ) -> CGPoint? {
        guard let heroSticky,
              let heroRegion = snapshot.regions.first(where: { $0.workspaceID == heroSticky.workspaceID }) else {
            return nil
        }
        if let preview = heroRegion.stickyPreviews.first(where: { $0.id == heroSticky.id }) {
            let previewCenterX = CGFloat(preview.x + (preview.width / 2))
            let previewCenterY = CGFloat(preview.y + (preview.height / 2))
            return CGPoint(
                x: heroRegion.frame.minX + (previewCenterX * heroRegion.frame.width),
                y: heroRegion.frame.minY + (previewCenterY * heroRegion.frame.height)
            )
        }
        return CGPoint(
            x: heroRegion.frame.minX + heroSticky.position.x + (heroSticky.size.width / 2),
            y: heroRegion.frame.minY + heroSticky.position.y + (heroSticky.size.height / 2)
        )
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
    var backgroundSnapshotImage: CGImage?

    override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext,
           let backgroundSnapshotImage {
            context.saveGState()
            context.interpolationQuality = .high
            context.draw(backgroundSnapshotImage, in: bounds)
            context.restoreGState()
        } else {
            NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 0.98).setFill()
            dirtyRect.fill()
        }

        let overlayAlpha = min(max(transitionProgress, 0), 1)
        guard overlayAlpha > 0 else {
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }
        context.saveGState()
        context.setAlpha(overlayAlpha)
        drawOverlay(in: dirtyRect)
        context.restoreGState()
    }

    private func drawOverlay(in dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 0.98).setFill()
        dirtyRect.fill()

        guard let contentBounds = contentBounds() else {
            drawHeader()
            return
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

    func screenPoint(forCanvasPoint canvasPoint: CGPoint) -> CGPoint? {
        guard let contentBounds = contentBounds() else {
            return nil
        }
        let base = centeredBase(contentBounds: contentBounds, scale: displayScale)
        return transformedPoint(
            canvasPoint,
            base: base,
            scale: displayScale,
            panOffset: panOffset
        )
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

    private func contentBounds() -> CGRect? {
        guard let first = snapshot.regions.first else {
            return nil
        }
        return snapshot.regions.dropFirst().reduce(first.frame) { partial, region in
            partial.union(region.frame)
        }
    }

    private func transformed(_ rect: CGRect, base: CGPoint, scale: CGFloat, panOffset: CGPoint) -> CGRect {
        CGRect(
            x: (rect.origin.x * scale) + base.x + panOffset.x,
            y: (rect.origin.y * scale) + base.y + panOffset.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private func transformedPoint(_ point: CGPoint, base: CGPoint, scale: CGFloat, panOffset: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x * scale) + base.x + panOffset.x,
            y: (point.y * scale) + base.y + panOffset.y
        )
    }
}
#else
public actor AppKitZoomOutOverviewPresenter: ZoomOutOverviewPresenting {
    public init(captureProvider: any DesktopCaptureProviding = NoopDesktopCapture()) {}

    public func present(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}

    public func preparePresentation(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {}

    public func animatePreparedPresentation() async {}

    public func hide() async {}

    public func latestAnimationMetrics() async -> ZoomOutAnimationMetrics? { nil }

    public func backgroundCaptureResult() -> BackgroundCaptureResult? { nil }
}
#endif
