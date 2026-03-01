import CoreGraphics
import Foundation

public struct PanelCanvasAlignmentContract: Sendable, Equatable {
    public let canvasOriginInScreenCoords: CGPoint
    public let scale: CGFloat

    public init(canvasOriginInScreenCoords: CGPoint, scale: CGFloat) {
        self.canvasOriginInScreenCoords = canvasOriginInScreenCoords
        self.scale = max(scale, 0.000_001)
    }

    public func panelToCanvas(_ panelScreenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (panelScreenPoint.x - canvasOriginInScreenCoords.x) * (1.0 / scale),
            y: (panelScreenPoint.y - canvasOriginInScreenCoords.y) * (1.0 / scale)
        )
    }

    public func canvasToScreen(_ canvasPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (canvasPoint.x * scale) + canvasOriginInScreenCoords.x,
            y: (canvasPoint.y * scale) + canvasOriginInScreenCoords.y
        )
    }
}
