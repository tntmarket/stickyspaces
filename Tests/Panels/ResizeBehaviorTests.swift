import Testing
import Foundation
@testable import StickySpacesApp

#if canImport(AppKit)
import AppKit

@Suite("Edge and corner resize behavior")
struct ResizeBehaviorTests {

    @Test("Right-edge resize commits updated size via delegate")
    @MainActor func rightEdgeResizePersistsSize() {
        let stickyID = UUID()
        let recorder = ResizeDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let rightEdgePoint = NSPoint(x: contentView.bounds.maxX - 2, y: contentView.bounds.midY)

        simulateResize(on: contentView, panel: panel, from: rightEdgePoint, dx: 50, dy: 0)

        #expect(recorder.resizes.count == 1)
        #expect(recorder.resizes.first?.stickyID == stickyID)
        #expect(recorder.resizes.first!.size.width > 320)
    }

    @Test("Resize clamps to minimum 120x80")
    @MainActor func resizeClampsToMinimumSize() {
        let stickyID = UUID()
        let recorder = ResizeDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let rightEdgePoint = NSPoint(x: contentView.bounds.maxX - 2, y: contentView.bounds.midY)

        simulateResize(on: contentView, panel: panel, from: rightEdgePoint, dx: -300, dy: 0)

        #expect(recorder.resizes.count == 1)
        let resize = recorder.resizes.first!
        #expect(resize.size.width >= 120)
        #expect(resize.size.height >= 80)
    }

    @Test("Mouse down outside edge zones does not start resize")
    @MainActor func centerClickDoesNotResize() {
        let stickyID = UUID()
        let recorder = ResizeDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let centerPoint = NSPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)

        simulateResize(on: contentView, panel: panel, from: centerPoint, dx: 50, dy: 0)

        #expect(recorder.resizes.isEmpty)
    }

    @Test("Corner resize changes both width and height")
    @MainActor func cornerResizePersistsSize() {
        let stickyID = UUID()
        let recorder = ResizeDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let cornerPoint = NSPoint(x: contentView.bounds.maxX - 2, y: 2)

        simulateResize(on: contentView, panel: panel, from: cornerPoint, dx: 40, dy: -30)

        #expect(recorder.resizes.count == 1)
        let resize = recorder.resizes.first!
        #expect(resize.size.width > 320)
        #expect(resize.size.height > 220)
    }

    @Test("Resize does not activate the app")
    @MainActor func resizeDoesNotActivateApp() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)

        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.styleMask.contains(.titled))
    }

    @Test("Mouse exit during active resize does not reset cursor")
    @MainActor func mouseExitDuringResizeKeepsCursor() {
        let panel = StickyPanel(stickyID: UUID(), delegate: nil)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let rightEdgePoint = NSPoint(x: contentView.bounds.maxX - 2, y: contentView.bounds.midY)

        let moveEvent = NSEvent.mouseEvent(
            with: .mouseMoved, location: rightEdgePoint,
            modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 0, pressure: 0
        )!
        contentView.mouseMoved(with: moveEvent)
        #expect(NSCursor.current == NSCursor.resizeLeftRight)

        let mouseDown = NSEvent.mouseEvent(
            with: .leftMouseDown, location: rightEdgePoint,
            modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 0
        )!
        contentView.mouseDown(with: mouseDown)

        let exitEvent = NSEvent.otherEvent(
            with: .applicationDefined,
            location: NSPoint(x: -10, y: -10),
            modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber,
            context: nil, subtype: 0, data1: 0, data2: 0
        )!
        contentView.mouseExited(with: exitEvent)

        #expect(NSCursor.current == NSCursor.resizeLeftRight)
    }

    @Test("Left-edge resize adjusts origin and width")
    @MainActor func leftEdgeResizeChangesOriginAndWidth() {
        let stickyID = UUID()
        let recorder = ResizeDelegateRecorder()
        let panel = StickyPanel(stickyID: stickyID, delegate: recorder)
        panel.setFrame(NSRect(x: 100, y: 100, width: 320, height: 220), display: true)
        panel.orderFrontRegardless()

        let contentView = panel.stickyContentView
        let leftEdgePoint = NSPoint(x: 2, y: contentView.bounds.midY)

        simulateResize(on: contentView, panel: panel, from: leftEdgePoint, dx: -50, dy: 0)

        #expect(recorder.resizes.count == 1)
        let resize = recorder.resizes.first!
        #expect(resize.size.width > 320)
        #expect(resize.position.x < 100)
    }
}

// MARK: - Helpers

@MainActor
private func simulateResize(
    on contentView: StickyContentView,
    panel: StickyPanel,
    from point: NSPoint,
    dx: CGFloat,
    dy: CGFloat
) {
    let mouseDown = NSEvent.mouseEvent(
        with: .leftMouseDown, location: point,
        modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 0
    )!
    contentView.mouseDown(with: mouseDown)

    let dragPoint = NSPoint(x: point.x + dx, y: point.y + dy)
    let mouseDrag = NSEvent.mouseEvent(
        with: .leftMouseDragged, location: dragPoint,
        modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
        context: nil, eventNumber: 0, clickCount: 0, pressure: 0
    )!
    contentView.mouseDragged(with: mouseDrag)

    let mouseUp = NSEvent.mouseEvent(
        with: .leftMouseUp, location: dragPoint,
        modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 0
    )!
    contentView.mouseUp(with: mouseUp)
}

@MainActor
private final class ResizeDelegateRecorder: StickyPanelDelegate {
    struct ResizeRecord { let stickyID: UUID; let size: CGSize; let position: CGPoint }
    var resizes: [ResizeRecord] = []

    func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint) {}
    func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint) {
        resizes.append(ResizeRecord(stickyID: stickyID, size: size, position: position))
    }
    func stickyPanel(_ stickyID: UUID, didChangeText text: String) {}
    func stickyPanelDidRequestDismiss(_ stickyID: UUID) {}
}

#endif
