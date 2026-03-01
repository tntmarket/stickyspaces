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

public struct CanvasRegionSnapshot: Codable, Sendable, Equatable {
    public let workspaceID: WorkspaceID
    public let displayID: Int
    public let frame: CGRect
    public let stickyCount: Int
    public let isActive: Bool

    public init(
        workspaceID: WorkspaceID,
        displayID: Int,
        frame: CGRect,
        stickyCount: Int,
        isActive: Bool
    ) {
        self.workspaceID = workspaceID
        self.displayID = displayID
        self.frame = frame
        self.stickyCount = stickyCount
        self.isActive = isActive
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
