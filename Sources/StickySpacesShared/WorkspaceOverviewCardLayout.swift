import CoreGraphics
import Foundation

public struct WorkspaceOverviewCardLayout: Sendable, Equatable {
    public static let labelHeight: CGFloat = 16
    public static let labelGap: CGFloat = 7

    public let cardRect: CGRect
    public let workspaceRect: CGRect
    public let intentLabelRect: CGRect
    public let labelText: String?

    public init(
        cardRect: CGRect,
        workspaceRect: CGRect,
        intentLabelRect: CGRect,
        labelText: String?
    ) {
        self.cardRect = cardRect
        self.workspaceRect = workspaceRect
        self.intentLabelRect = intentLabelRect
        self.labelText = labelText
    }

    public static func make(
        workspaceRect: CGRect,
        stickyPreviews: [CanvasStickyPreview],
        scale: Double
    ) -> WorkspaceOverviewCardLayout {
        _ = scale // Label stays fixed-size for readability at overview zoom.
        let sortedPreviews = stickyPreviews.sorted(by: stickyPreviewOrder)
        let labelText = buildLabelText(previews: sortedPreviews)
        let intentLabelRect = CGRect(
            x: workspaceRect.minX,
            y: workspaceRect.minY - labelHeight - labelGap,
            width: workspaceRect.width,
            height: labelHeight
        )
        let cardRect = labelText == nil ? workspaceRect : workspaceRect.union(intentLabelRect)
        return WorkspaceOverviewCardLayout(
            cardRect: cardRect,
            workspaceRect: workspaceRect,
            intentLabelRect: intentLabelRect,
            labelText: labelText
        )
    }

    private static func buildLabelText(previews: [CanvasStickyPreview]) -> String? {
        guard let first = previews.first else {
            return nil
        }
        let extraCount = max(0, previews.count - 1)
        if extraCount == 0 {
            return first.displayHeader
        }
        return "\(first.displayHeader) +\(extraCount)"
    }

    private static func stickyPreviewOrder(_ lhs: CanvasStickyPreview, _ rhs: CanvasStickyPreview) -> Bool {
        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }
        if lhs.x != rhs.x {
            return lhs.x < rhs.x
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
