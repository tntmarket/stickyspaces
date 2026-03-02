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

public enum CanvasThumbnailSource: String, Codable, Sendable, Equatable {
    case synthetic
    case cachedCapture
    case liveCapture
    case unavailable
}

public struct CanvasThumbnailMetadata: Codable, Sendable, Equatable {
    public let source: CanvasThumbnailSource
    public let capturedAt: Date?
    public let displayID: Int?
    public let unavailableReason: String?

    public init(
        source: CanvasThumbnailSource,
        capturedAt: Date? = nil,
        displayID: Int? = nil,
        unavailableReason: String? = nil
    ) {
        self.source = source
        self.capturedAt = capturedAt
        self.displayID = displayID
        self.unavailableReason = unavailableReason
    }

    public static let synthetic = CanvasThumbnailMetadata(source: .synthetic)

    public var isCaptureBased: Bool {
        source == .cachedCapture || source == .liveCapture
    }

    public func isStale(now: Date = Date(), staleAfter: TimeInterval) -> Bool {
        guard staleAfter >= 0, isCaptureBased, let capturedAt else {
            return false
        }
        return now.timeIntervalSince(capturedAt) > staleAfter
    }

    public func markingStale(now: Date = Date(), staleAfter: TimeInterval) -> CanvasThumbnailMetadata {
        guard isCaptureBased else {
            return self
        }
        let staleAt = now.addingTimeInterval(-(max(0, staleAfter) + 1))
        return CanvasThumbnailMetadata(
            source: source,
            capturedAt: staleAt,
            displayID: displayID,
            unavailableReason: unavailableReason
        )
    }
}

public struct CanvasRegionSnapshot: Codable, Sendable, Equatable {
    public let workspaceID: WorkspaceID
    public let displayID: Int
    public let frame: CGRect
    public let stickyCount: Int
    public let isActive: Bool
    public let stickyPreviews: [CanvasStickyPreview]
    public let thumbnail: CanvasThumbnailMetadata

    public init(
        workspaceID: WorkspaceID,
        displayID: Int,
        frame: CGRect,
        stickyCount: Int,
        isActive: Bool,
        stickyPreviews: [CanvasStickyPreview] = [],
        thumbnail: CanvasThumbnailMetadata = .synthetic
    ) {
        self.workspaceID = workspaceID
        self.displayID = displayID
        self.frame = frame
        self.stickyCount = stickyCount
        self.isActive = isActive
        self.stickyPreviews = stickyPreviews
        self.thumbnail = thumbnail
    }

    private enum CodingKeys: String, CodingKey {
        case workspaceID
        case displayID
        case frame
        case stickyCount
        case isActive
        case stickyPreviews
        case thumbnail
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaceID = try container.decode(WorkspaceID.self, forKey: .workspaceID)
        displayID = try container.decode(Int.self, forKey: .displayID)
        frame = try container.decode(CGRect.self, forKey: .frame)
        stickyCount = try container.decode(Int.self, forKey: .stickyCount)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        stickyPreviews = try container.decodeIfPresent([CanvasStickyPreview].self, forKey: .stickyPreviews) ?? []
        thumbnail = try container.decodeIfPresent(CanvasThumbnailMetadata.self, forKey: .thumbnail) ?? .synthetic
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workspaceID, forKey: .workspaceID)
        try container.encode(displayID, forKey: .displayID)
        try container.encode(frame, forKey: .frame)
        try container.encode(stickyCount, forKey: .stickyCount)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(stickyPreviews, forKey: .stickyPreviews)
        try container.encode(thumbnail, forKey: .thumbnail)
    }

    public func updatingThumbnail(_ thumbnail: CanvasThumbnailMetadata) -> CanvasRegionSnapshot {
        CanvasRegionSnapshot(
            workspaceID: workspaceID,
            displayID: displayID,
            frame: frame,
            stickyCount: stickyCount,
            isActive: isActive,
            stickyPreviews: stickyPreviews,
            thumbnail: thumbnail
        )
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
