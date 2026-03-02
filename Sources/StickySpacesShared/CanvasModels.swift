import CoreGraphics
import Foundation

public struct CanvasLayout: Codable, Sendable, Equatable {
    public var workspacePositions: [WorkspaceID: CGPoint]
    public var workspaceDisplayIDs: [WorkspaceID: Int]

    public init(
        workspacePositions: [WorkspaceID: CGPoint] = [:],
        workspaceDisplayIDs: [WorkspaceID: Int] = [:]
    ) {
        self.workspacePositions = workspacePositions
        self.workspaceDisplayIDs = workspaceDisplayIDs
    }
}

public struct CanvasViewportState: Codable, Sendable, Equatable {
    public var zoomScale: Double
    public var panOffset: CGPoint

    public init(zoomScale: Double, panOffset: CGPoint) {
        self.zoomScale = zoomScale
        self.panOffset = panOffset
    }

    public static let defaultOverview = CanvasViewportState(
        zoomScale: 0.35,
        panOffset: CGPoint(x: 0, y: 0)
    )
}

public struct CanvasStickyPreview: Codable, Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let header: String?
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
        id: UUID,
        text: String,
        header: String?,
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.id = id
        self.text = text
        self.header = header
        self.x = CanvasStickyPreview.clampedUnit(x)
        self.y = CanvasStickyPreview.clampedUnit(y)
        self.width = CanvasStickyPreview.clampedUnit(width)
        self.height = CanvasStickyPreview.clampedUnit(height)
    }

    public var normalizedFrame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    public var displayHeader: String {
        StickyNote.resolvedHeader(header: header, text: text)
    }

    private static func clampedUnit(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public struct CanvasRegionSnapshot: Codable, Sendable, Equatable {
    public let workspaceID: WorkspaceID
    public let displayID: Int
    public let frame: CGRect
    public let stickyCount: Int
    public let isActive: Bool
    public let stickyPreviews: [CanvasStickyPreview]

    public init(
        workspaceID: WorkspaceID,
        displayID: Int,
        frame: CGRect,
        stickyCount: Int,
        isActive: Bool,
        stickyPreviews: [CanvasStickyPreview] = []
    ) {
        self.workspaceID = workspaceID
        self.displayID = displayID
        self.frame = frame
        self.stickyCount = stickyCount
        self.isActive = isActive
        self.stickyPreviews = stickyPreviews
    }

    private enum CodingKeys: String, CodingKey {
        case workspaceID
        case displayID
        case frame
        case stickyCount
        case isActive
        case stickyPreviews
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaceID = try container.decode(WorkspaceID.self, forKey: .workspaceID)
        displayID = try container.decode(Int.self, forKey: .displayID)
        frame = try container.decode(CGRect.self, forKey: .frame)
        stickyCount = try container.decode(Int.self, forKey: .stickyCount)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        stickyPreviews = try container.decodeIfPresent([CanvasStickyPreview].self, forKey: .stickyPreviews) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workspaceID, forKey: .workspaceID)
        try container.encode(displayID, forKey: .displayID)
        try container.encode(frame, forKey: .frame)
        try container.encode(stickyCount, forKey: .stickyCount)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(stickyPreviews, forKey: .stickyPreviews)
    }
}

public struct CanvasSnapshot: Codable, Sendable, Equatable {
    public let viewport: CanvasViewportState
    public let activeWorkspaceID: WorkspaceID?
    public let regions: [CanvasRegionSnapshot]
    public let invariants: [String]

    public init(
        viewport: CanvasViewportState,
        activeWorkspaceID: WorkspaceID?,
        regions: [CanvasRegionSnapshot],
        invariants: [String]
    ) {
        self.viewport = viewport
        self.activeWorkspaceID = activeWorkspaceID
        self.regions = regions
        self.invariants = invariants
    }
}
