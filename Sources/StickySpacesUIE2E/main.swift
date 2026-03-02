import Foundation
import StickySpacesApp
import StickySpacesShared

#if canImport(AppKit)
import AppKit

@main
enum StickySpacesUIE2ERunner {
    @MainActor private static var canvasWindowController: CanvasMarketingWindowController?

    static func main() async throws {
        let config = RunnerConfig(arguments: CommandLine.arguments)
        if config.showHelp {
            print(RunnerConfig.helpText)
            return
        }

        let workspace = WorkspaceID(rawValue: config.workspaceID)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        let panelSync = AppKitPanelSync()
        let manager = StickyManager(store: StickyStore(), yabai: yabai, panelSync: panelSync)

        _ = await MainActor.run {
            NSApplication.shared
        }

        print("Running scenario \(config.scenario.rawValue)")
        print(config.scenario.description)
        try await runScenario(config.scenario, manager: manager, yabai: yabai, panelSync: panelSync)

        let deadline = Date().addingTimeInterval(config.durationSeconds)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }

        try await manager.dismissAllStickiesOnCurrentWorkspace()
        print("UI E2E demo complete; dismissed remaining stickies.")
    }

    private static func runScenario(
        _ scenario: UIScenario,
        manager: StickyManager,
        yabai: FakeYabaiQuerying,
        panelSync: AppKitPanelSync
    ) async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))

        switch scenario {
        case .fr1CreateSticky:
            let first = try await manager.createSticky(text: "FR-1: Created via command path")
            try await manager.updateStickyPosition(id: first.sticky.id, x: 120, y: 620)

        case .fr2WorkspaceVisibility:
            await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))
            _ = try await manager.createSticky(text: "Workspace 1 sticky")
            await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
            _ = try await manager.createSticky(text: "Workspace 2 sticky")
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace1)
            try? await Task.sleep(for: .seconds(1))
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace2)

        case .fr3EditInPlace:
            let created = try await manager.createSticky(text: "FR-3 Before")
            try? await Task.sleep(for: .milliseconds(700))
            try await manager.updateStickyText(id: created.sticky.id, text: "FR-3 After")

        case .fr4MoveResize:
            let created = try await manager.createSticky(text: "FR-4 move + resize")
            try await manager.updateStickyPosition(id: created.sticky.id, x: 200, y: 500)
            try await manager.updateStickySize(id: created.sticky.id, width: 420, height: 260)

        case .fr5MultipleStickies:
            let first = try await manager.createSticky(text: "FR-5 Sticky A")
            try await manager.updateStickyPosition(id: first.sticky.id, x: 100, y: 610)
            let second = try await manager.createSticky(text: "FR-5 Sticky B")
            try await manager.updateStickyPosition(id: second.sticky.id, x: 430, y: 560)
            let third = try await manager.createSticky(text: "FR-5 Sticky C")
            try await manager.updateStickyPosition(id: third.sticky.id, x: 760, y: 510)

        case .fr6DismissSticky:
            let first = try await manager.createSticky(text: "FR-6 Keep")
            let second = try await manager.createSticky(text: "FR-6 Dismiss Me")
            try await manager.updateStickyPosition(id: first.sticky.id, x: 120, y: 600)
            try await manager.updateStickyPosition(id: second.sticky.id, x: 520, y: 560)
            try? await Task.sleep(for: .seconds(1))
            try await manager.dismissSticky(id: second.sticky.id)

        case .fr7ZoomOutCanvas:
            let first = try await manager.createSticky(text: "FR-7 A")
            try await manager.updateStickyPosition(id: first.sticky.id, x: 210, y: 640)
            await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
            let second = try await manager.createSticky(text: "FR-7 B")
            try await manager.updateStickyPosition(id: second.sticky.id, x: 280, y: 420)
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace2)
            let snapshot = try await manager.zoomOutSnapshot()
            print("zoom-out regions=\(snapshot.regions.count) active=\(snapshot.activeWorkspaceID?.rawValue.description ?? "none")")
            await showCanvasExperience(
                snapshot: snapshot,
                manager: manager,
                panelSync: panelSync
            )

        case .fr8NavigateBySticky:
            await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
            let target = try await manager.createSticky(text: "FR-8 Target workspace 2")
            await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace1)
            try? await Task.sleep(for: .seconds(1))
            try await manager.navigateFromCanvasClick(stickyID: target.sticky.id)
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace2)

        case .fr9ArrangeRegions:
            await manager.setWorkspacePosition(workspace1, position: CGPoint(x: 80, y: 120))
            await manager.setWorkspacePosition(workspace2, position: CGPoint(x: 540, y: 180))
            await manager.setWorkspacePosition(workspace3, position: CGPoint(x: 980, y: 260))
            let layout = try await manager.canvasLayout()
            print("canvas-layout positions=\(layout.workspacePositions.count)")
            let snapshot = try await manager.zoomOutSnapshot()
            await showCanvasExperience(
                snapshot: snapshot,
                manager: manager,
                panelSync: panelSync
            )

        case .fr10ActiveWorkspaceHighlight:
            _ = try await manager.createSticky(text: "FR-10 highlight source")
            await yabai.setCurrentBinding(.stable(workspaceID: workspace3, displayID: 1, isPrimaryDisplay: true))
            _ = try await manager.createSticky(text: "FR-10 highlight target")
            let snapshot = try await manager.zoomOutSnapshot()
            print("active-workspace-highlight=\(snapshot.activeWorkspaceID?.rawValue.description ?? "none")")
            await showCanvasExperience(
                snapshot: snapshot,
                manager: manager,
                panelSync: panelSync
            )

        case .fr11DestroyedWorkspace:
            await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
            let doomed = try await manager.createSticky(text: "FR-11 doomed workspace sticky")
            await showOnlyWorkspace(manager: manager, panelSync: panelSync, workspaceID: workspace2)
            try? await Task.sleep(for: .seconds(1))

            await panelSync.hide(stickyID: doomed.sticky.id, workspaceID: workspace2)
            print("workspace 2 sticky hidden from visible surfaces")

            let healthyNow = Date()
            let reduced = WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
            _ = await manager.reconcileTopology(snapshot: reduced, health: .healthy, now: healthyNow)
            _ = await manager.reconcileTopology(
                snapshot: reduced,
                health: .healthy,
                now: healthyNow.addingTimeInterval(3)
            )
            let remaining = await manager.list(space: workspace2)
            print("workspace 2 remaining stickies after confirmation=\(remaining.count)")
        }
    }

    private static func showOnlyWorkspace(
        manager: StickyManager,
        panelSync: AppKitPanelSync,
        workspaceID: WorkspaceID
    ) async {
        let all = await manager.list(space: nil)
        for sticky in all {
            if sticky.workspaceID == workspaceID {
                await panelSync.show(sticky: sticky)
            } else {
                await panelSync.hide(stickyID: sticky.id, workspaceID: sticky.workspaceID)
            }
        }
    }

    private static func showCanvasExperience(
        snapshot: CanvasSnapshot,
        manager: StickyManager,
        panelSync: AppKitPanelSync
    ) async {
        let notes = await manager.list(space: nil)
        let heroSticky = pickHeroSticky(notes: notes, activeWorkspaceID: snapshot.activeWorkspaceID)
        let controller = await MainActor.run { () -> CanvasMarketingWindowController in
            let existing = canvasWindowController ?? CanvasMarketingWindowController()
            canvasWindowController = existing
            return existing
        }
        await controller.prepare(snapshot: snapshot, heroSticky: heroSticky)
        await hideAllVisiblePanels(manager: manager, panelSync: panelSync)
        await controller.animateZoomOut()
    }

    private static func hideAllVisiblePanels(
        manager: StickyManager,
        panelSync: AppKitPanelSync
    ) async {
        let notes = await manager.list(space: nil)
        for note in notes {
            await panelSync.hide(stickyID: note.id, workspaceID: note.workspaceID)
        }
    }

    private static func pickHeroSticky(
        notes: [StickyNote],
        activeWorkspaceID: WorkspaceID?
    ) -> StickyNote? {
        guard let activeWorkspaceID else {
            return notes.sorted { $0.createdAt < $1.createdAt }.last
        }
        let activeNotes = notes
            .filter { $0.workspaceID == activeWorkspaceID }
            .sorted { $0.createdAt < $1.createdAt }
        return activeNotes.last ?? notes.sorted { $0.createdAt < $1.createdAt }.last
    }
}

@MainActor
private final class CanvasMarketingWindowController {
    private let panel: NSPanel
    private let canvasView: CanvasMarketingView

    init() {
        panel = NSPanel(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
        panel.isOpaque = false

        canvasView = CanvasMarketingView(frame: panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1440, height: 900))
        canvasView.autoresizingMask = [.width, .height]
        panel.contentView = canvasView
    }

    func prepare(snapshot: CanvasSnapshot, heroSticky: StickyNote?) async {
        if let screenFrame = NSScreen.main?.frame {
            panel.setFrame(screenFrame, display: true)
            canvasView.frame = panel.contentView?.bounds ?? canvasView.frame
        }
        panel.orderOut(nil)
        canvasView.setDesktopSnapshot(CGDisplayCreateImage(CGMainDisplayID()))
        canvasView.snapshot = snapshot
        let endScale: CGFloat = max(0.2, CGFloat(snapshot.viewport.zoomScale))
        let endPan = CGPoint(x: snapshot.viewport.panOffset.x, y: snapshot.viewport.panOffset.y)
        let heroStartRect = heroSticky.map { sticky in
            let screenRect = CGRect(origin: sticky.position, size: sticky.size)
            return screenRect.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY)
        }
        let startScale: CGFloat
        let startPan: CGPoint
        if canvasView.hasDesktopSnapshot {
            startScale = canvasView.scaleFillingActiveWorkspace()
            startPan = canvasView.panOffsetCenteringActiveWorkspace(scale: startScale)
        } else {
            startScale = 1.18
            startPan = canvasView.panOffsetContextualizingHero(
                scale: startScale,
                heroRect: heroStartRect
            )
        }
        let heroEndRect = canvasView.heroTargetRect(
            scale: endScale,
            pan: endPan,
            heroStartRect: heroStartRect
        )
        canvasView.configureHeroTransition(start: heroStartRect, end: heroEndRect)

        panel.alphaValue = 1
        panel.ignoresMouseEvents = true
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)

        canvasView.displayScale = startScale
        canvasView.panOffset = startPan
        canvasView.transitionProgress = 0
        canvasView.needsDisplay = true
    }

    func animateZoomOut() async {
        let startScale = canvasView.displayScale
        let endScale = max(0.2, CGFloat(canvasView.snapshot.viewport.zoomScale))
        let startPan = canvasView.panOffset
        let endPan = CGPoint(
            x: canvasView.snapshot.viewport.panOffset.x,
            y: canvasView.snapshot.viewport.panOffset.y
        )

        // Keep the hero sticky fixed briefly so the user perceives a clean swap
        // from panel -> canvas at identical position/size before zooming out.
        canvasView.transitionProgress = 0
        canvasView.needsDisplay = true
        try? await Task.sleep(for: .milliseconds(260))

        let frameCount = 28
        for frame in 0...frameCount {
            let t = CGFloat(frame) / CGFloat(frameCount)
            let eased = t * t * (3 - (2 * t))
            canvasView.displayScale = interpolate(from: startScale, to: endScale, progress: eased)
            canvasView.panOffset = CGPoint(
                x: interpolate(from: startPan.x, to: endPan.x, progress: eased),
                y: interpolate(from: startPan.y, to: endPan.y, progress: eased)
            )
            canvasView.transitionProgress = eased
            canvasView.needsDisplay = true
            try? await Task.sleep(for: .milliseconds(18))
        }
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + ((to - from) * progress)
    }
}

@MainActor
private final class CanvasMarketingView: NSView {
    var snapshot = CanvasSnapshot(
        viewport: .defaultOverview,
        activeWorkspaceID: nil,
        regions: [],
        invariants: []
    )
    var displayScale: CGFloat = 1
    var panOffset: CGPoint = .zero
    var transitionProgress: CGFloat = 1

    private var heroStartRect: CGRect?
    private var heroEndRect: CGRect?
    private var desktopSnapshotImage: NSImage?
    private var desktopSnapshotAspectRatio: CGFloat?

    var hasDesktopSnapshot: Bool { desktopSnapshotImage != nil }

    func setDesktopSnapshot(_ snapshot: CGImage?) {
        guard let snapshot else {
            desktopSnapshotImage = nil
            desktopSnapshotAspectRatio = nil
            return
        }
        desktopSnapshotImage = NSImage(
            cgImage: snapshot,
            size: NSSize(width: snapshot.width, height: snapshot.height)
        )
        desktopSnapshotAspectRatio = CGFloat(snapshot.width) / max(1, CGFloat(snapshot.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 1.0).setFill()
        dirtyRect.fill()

        let canvasBounds = regionUnionBounds()
        let base = centeredBase(bounds: bounds, content: canvasBounds, scale: displayScale)
        var activeRegion: CanvasRegionSnapshot?
        var activeRegionRect: CGRect?
        for region in snapshot.regions {
            let transformed = transformedRect(region.frame, base: base, scale: displayScale, pan: panOffset)
            let rect = adjustedWorkspaceRectForSnapshotAspect(transformed)
            if region.isActive {
                activeRegion = region
                activeRegionRect = rect
                continue
            }
            drawRegion(region, in: rect, hidePrimaryStickyMarker: false)
        }

        if let activeRegionRect, let desktopSnapshotImage {
            drawDesktopWorkspaceSnapshot(
                desktopSnapshotImage,
                in: activeRegionRect
            )
        } else if let activeRegion, let activeRegionRect {
            drawRegion(
                activeRegion,
                in: activeRegionRect,
                hidePrimaryStickyMarker: heroStartRect != nil
            )
            if let heroRect = currentHeroRect() {
                drawHeroSticky(in: heroRect)
            }
        }
    }

    func panOffsetCenteringActiveWorkspace(scale: CGFloat) -> CGPoint {
        guard let active = snapshot.regions.first(where: { $0.isActive }) else {
            return .zero
        }
        let canvasBounds = regionUnionBounds()
        let base = centeredBase(bounds: bounds, content: canvasBounds, scale: scale)
        let transformedActiveRect = transformedRect(active.frame, base: base, scale: scale, pan: .zero)
        let activeRect = adjustedWorkspaceRectForSnapshotAspect(transformedActiveRect)
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let activeCenter = CGPoint(x: activeRect.midX, y: activeRect.midY)
        return CGPoint(x: viewCenter.x - activeCenter.x, y: viewCenter.y - activeCenter.y)
    }

    func scaleFillingActiveWorkspace() -> CGFloat {
        guard let active = snapshot.regions.first(where: { $0.isActive }) else {
            return 1.18
        }
        let activeWidth = max(1, active.frame.width)
        let activeHeight = max(1, active.frame.height)
        let activeAspect = activeWidth / activeHeight
        let targetAspect = desktopSnapshotAspectRatio ?? (bounds.width / max(1, bounds.height))
        if activeAspect >= targetAspect {
            return bounds.height / activeHeight
        }
        return bounds.width / activeWidth
    }

    func panOffsetContextualizingHero(scale: CGFloat, heroRect: CGRect?) -> CGPoint {
        guard
            let active = snapshot.regions.first(where: { $0.isActive }),
            let heroRect
        else {
            return panOffsetCenteringActiveWorkspace(scale: scale)
        }

        let base = centeredBase(bounds: bounds, content: regionUnionBounds(), scale: scale)
        let transformedActiveRect = transformedRect(active.frame, base: base, scale: scale, pan: .zero)
        let activeRect = adjustedWorkspaceRectForSnapshotAspect(transformedActiveRect)
        let anchor = CGPoint(
            x: activeRect.minX + max(16, activeRect.width * 0.14),
            y: activeRect.maxY - max(20, activeRect.height * 0.20)
        )
        let heroCenter = CGPoint(x: heroRect.midX, y: heroRect.midY)
        return CGPoint(x: heroCenter.x - anchor.x, y: heroCenter.y - anchor.y)
    }

    func configureHeroTransition(start: CGRect?, end: CGRect?) {
        heroStartRect = start
        heroEndRect = end
    }

    func heroTargetRect(scale: CGFloat, pan: CGPoint, heroStartRect: CGRect?) -> CGRect? {
        guard let active = snapshot.regions.first(where: { $0.isActive }) else {
            return nil
        }
        let base = centeredBase(bounds: bounds, content: regionUnionBounds(), scale: scale)
        let transformedActiveRect = transformedRect(active.frame, base: base, scale: scale, pan: pan)
        let activeRect = adjustedWorkspaceRectForSnapshotAspect(transformedActiveRect)
        guard let heroStartRect else {
            let width = max(24, activeRect.width * 0.16)
            let height = max(18, activeRect.height * 0.12)
            return CGRect(
                x: activeRect.minX + max(14, activeRect.width * 0.08),
                y: activeRect.maxY - height - max(16, activeRect.height * 0.10),
                width: width,
                height: height
            )
        }

        // Preserve proportional desktop position/size inside the active workspace box.
        let normalized = normalizedRect(heroStartRect, inside: bounds)
        let rawTarget = CGRect(
            x: activeRect.minX + (activeRect.width * normalized.minX),
            y: activeRect.minY + (activeRect.height * normalized.minY),
            width: activeRect.width * normalized.width,
            height: activeRect.height * normalized.height
        )
        return clampRect(rawTarget, inside: activeRect)
    }

    private func currentHeroRect() -> CGRect? {
        guard let start = heroStartRect else {
            return nil
        }
        guard let end = heroEndRect else {
            return start
        }
        let t = max(0, min(1, transitionProgress))
        return CGRect(
            x: interpolate(from: start.minX, to: end.minX, progress: t),
            y: interpolate(from: start.minY, to: end.minY, progress: t),
            width: interpolate(from: start.width, to: end.width, progress: t),
            height: interpolate(from: start.height, to: end.height, progress: t)
        )
    }

    private func regionUnionBounds() -> CGRect {
        guard let first = snapshot.regions.first else {
            return CGRect(x: 0, y: 0, width: 1000, height: 700)
        }
        return snapshot.regions.dropFirst().reduce(first.frame) { partial, region in
            partial.union(region.frame)
        }
    }

    private func centeredBase(bounds: CGRect, content: CGRect, scale: CGFloat) -> CGPoint {
        let scaledWidth = content.width * scale
        let scaledHeight = content.height * scale
        let x = (bounds.width - scaledWidth) / 2 - (content.origin.x * scale)
        let y = (bounds.height - scaledHeight) / 2 - (content.origin.y * scale)
        return CGPoint(x: x, y: y)
    }

    private func transformedRect(_ rect: CGRect, base: CGPoint, scale: CGFloat, pan: CGPoint) -> CGRect {
        CGRect(
            x: (rect.origin.x * scale) + base.x + pan.x,
            y: (rect.origin.y * scale) + base.y + pan.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private func drawRegion(
        _ region: CanvasRegionSnapshot,
        in rect: CGRect,
        hidePrimaryStickyMarker: Bool
    ) {
        let radius: CGFloat = 18
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let fillColor = region.isActive
            ? NSColor(calibratedRed: 0.27, green: 0.48, blue: 0.93, alpha: 0.95)
            : NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.22, alpha: 0.94)
        fillColor.setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        (region.isActive ? NSColor(calibratedRed: 0.72, green: 0.84, blue: 1.0, alpha: 1) : NSColor(calibratedWhite: 0.45, alpha: 0.9)).setStroke()
        border.lineWidth = region.isActive ? 3 : 1.5
        border.stroke()

        let markerCount: Int
        if hidePrimaryStickyMarker && region.isActive && region.stickyCount > 0 {
            markerCount = max(0, region.stickyCount - 1)
        } else {
            markerCount = region.stickyCount
        }
        for idx in 0..<min(markerCount, 5) {
            let noteRect = CGRect(
                x: rect.minX + 18 + CGFloat(idx * 28),
                y: rect.maxY - 62,
                width: 22,
                height: 18
            )
            let note = NSBezierPath(roundedRect: noteRect, xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.72, alpha: 0.97).setFill()
            note.fill()
        }
    }

    private func drawHeroSticky(in rect: CGRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.76, alpha: 1.0).setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        NSColor(calibratedWhite: 0.72, alpha: 0.85).setStroke()
        border.lineWidth = 1.2
        border.stroke()
    }

    private func drawDesktopWorkspaceSnapshot(_ image: NSImage, in rect: CGRect) {
        let t = max(0, min(1, transitionProgress))
        let cornerRadius = interpolate(from: 0, to: 18, progress: t)

        NSGraphicsContext.saveGraphicsState()
        let clip = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        clip.addClip()
        image.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(calibratedRed: 0.72, green: 0.84, blue: 1.0, alpha: 1).setStroke()
        border.lineWidth = interpolate(from: 2.2, to: 3.0, progress: t)
        border.stroke()
    }

    private func adjustedWorkspaceRectForSnapshotAspect(_ rect: CGRect) -> CGRect {
        guard
            let aspect = desktopSnapshotAspectRatio,
            aspect > 0,
            rect.width > 0,
            rect.height > 0
        else {
            return rect
        }
        let rectAspect = rect.width / rect.height
        if abs(rectAspect - aspect) < 0.0001 {
            return rect
        }
        if rectAspect > aspect {
            let width = rect.height * aspect
            return CGRect(
                x: rect.midX - (width / 2),
                y: rect.minY,
                width: width,
                height: rect.height
            )
        }
        let height = rect.width / aspect
        return CGRect(
            x: rect.minX,
            y: rect.midY - (height / 2),
            width: rect.width,
            height: height
        )
    }

    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + ((to - from) * progress)
    }

    private func normalizedRect(_ rect: CGRect, inside container: CGRect) -> CGRect {
        guard container.width > 0, container.height > 0 else {
            return CGRect(x: 0.1, y: 0.1, width: 0.15, height: 0.12)
        }
        return CGRect(
            x: rect.minX / container.width,
            y: rect.minY / container.height,
            width: rect.width / container.width,
            height: rect.height / container.height
        )
    }

    private func clampRect(_ rect: CGRect, inside container: CGRect) -> CGRect {
        let minWidth = min(max(14, container.width * 0.05), container.width)
        let minHeight = min(max(12, container.height * 0.05), container.height)
        let width = min(max(minWidth, rect.width), container.width)
        let height = min(max(minHeight, rect.height), container.height)
        let x = min(max(container.minX, rect.minX), container.maxX - width)
        let y = min(max(container.minY, rect.minY), container.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct RunnerConfig {
    let durationSeconds: TimeInterval
    let scenario: UIScenario
    let workspaceID: Int
    let showHelp: Bool

    init(arguments: [String]) {
        var durationSeconds: TimeInterval = 20
        var scenario: UIScenario = .fr1CreateSticky
        var workspaceID = 1
        var showHelp = false

        var index = 1
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--duration":
                if index + 1 < arguments.count, let value = Double(arguments[index + 1]) {
                    durationSeconds = max(1, value)
                    index += 1
                }
            case "--scenario":
                if index + 1 < arguments.count, let value = UIScenario(rawValue: arguments[index + 1]) {
                    scenario = value
                    index += 1
                }
            case "--workspace":
                if index + 1 < arguments.count, let value = Int(arguments[index + 1]) {
                    workspaceID = max(1, value)
                    index += 1
                }
            case "-h", "--help":
                showHelp = true
            default:
                break
            }
            index += 1
        }

        self.durationSeconds = durationSeconds
        self.scenario = scenario
        self.workspaceID = workspaceID
        self.showHelp = showHelp
    }

    static let helpText = """
    stickyspaces-ui-e2e options:
      --duration <seconds>       Total time to keep stickies visible (default: 20)
      --scenario <fr-id>         One of: \(UIScenario.allCases.map(\.rawValue).joined(separator: ", "))
      --workspace <id>           Fake workspace id for the demo (default: 1)
    """
}

private enum UIScenario: String, CaseIterable {
    case fr1CreateSticky = "fr-1"
    case fr2WorkspaceVisibility = "fr-2"
    case fr3EditInPlace = "fr-3"
    case fr4MoveResize = "fr-4"
    case fr5MultipleStickies = "fr-5"
    case fr6DismissSticky = "fr-6"
    case fr7ZoomOutCanvas = "fr-7"
    case fr8NavigateBySticky = "fr-8"
    case fr9ArrangeRegions = "fr-9"
    case fr10ActiveWorkspaceHighlight = "fr-10"
    case fr11DestroyedWorkspace = "fr-11"

    var description: String {
        switch self {
        case .fr1CreateSticky:
            return "FR-1: create a sticky on current workspace."
        case .fr2WorkspaceVisibility:
            return "FR-2: show stickies for the switched-to workspace."
        case .fr3EditInPlace:
            return "FR-3: edit sticky text in place."
        case .fr4MoveResize:
            return "FR-4: move and resize a sticky."
        case .fr5MultipleStickies:
            return "FR-5: multiple stickies on one workspace."
        case .fr6DismissSticky:
            return "FR-6: dismiss sticky removes it from view."
        case .fr7ZoomOutCanvas:
            return "FR-7: zoom-out snapshot over all workspaces."
        case .fr8NavigateBySticky:
            return "FR-8: navigate by sticky selection from canvas."
        case .fr9ArrangeRegions:
            return "FR-9: arrange workspace regions."
        case .fr10ActiveWorkspaceHighlight:
            return "FR-10: active workspace highlight in zoom-out."
        case .fr11DestroyedWorkspace:
            return "FR-11: workspace-destroyed visibility removal then hard-delete."
        }
    }
}
#else
@main
enum StickySpacesUIE2ERunner {
    static func main() {
        print("stickyspaces-ui-e2e requires AppKit on macOS.")
    }
}
#endif
