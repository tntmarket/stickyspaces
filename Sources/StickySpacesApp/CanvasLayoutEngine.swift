import CoreGraphics
import Foundation
import StickySpacesShared

public enum CanvasLayoutEngine {
    static let targetRegionArea: CGFloat = 153_600
    public static let defaultAspectRatio: CGFloat = 1.5
    private static let horizontalSpacing: CGFloat = 80
    private static let verticalSpacing: CGFloat = 80
    private static let columns = 3

    public static let regionSize = CGSize(width: 480, height: 320)

    public static func regionSize(forDisplayAspectRatio ratio: CGFloat) -> CGSize {
        let clamped = max(1.0, min(ratio, 3.0))
        let width = (targetRegionArea * clamped).squareRoot()
        let height = (targetRegionArea / clamped).squareRoot()
        return CGSize(width: width, height: height)
    }

    public static func resolveLayout(
        storedLayout: CanvasLayout,
        workspaces: [WorkspaceDescriptor],
        displayAspectRatio: CGFloat = defaultAspectRatio
    ) -> CanvasLayout {
        let size = regionSize(forDisplayAspectRatio: displayAspectRatio)
        let sortedWorkspaces = workspaces.sorted { $0.workspaceID.rawValue < $1.workspaceID.rawValue }
        var positions = storedLayout.workspacePositions
        var displayIDs = storedLayout.workspaceDisplayIDs

        for descriptor in sortedWorkspaces {
            displayIDs[descriptor.workspaceID] = descriptor.displayID
            if positions[descriptor.workspaceID] == nil {
                positions[descriptor.workspaceID] = nextDefaultPosition(occupied: Array(positions.values), size: size)
            }
        }

        let validIDs = Set(sortedWorkspaces.map(\.workspaceID))
        positions = positions.filter { validIDs.contains($0.key) }
        displayIDs = displayIDs.filter { validIDs.contains($0.key) }
        return CanvasLayout(workspacePositions: positions, workspaceDisplayIDs: displayIDs)
    }

    public static func makeSnapshot(
        layout: CanvasLayout,
        workspaces: [WorkspaceDescriptor],
        stickies: [StickyNote],
        activeWorkspaceID: WorkspaceID?,
        viewport: CanvasViewportState,
        displayAspectRatio: CGFloat = defaultAspectRatio
    ) -> CanvasSnapshot {
        let size = regionSize(forDisplayAspectRatio: displayAspectRatio)
        let stickiesByWorkspace = Dictionary(grouping: stickies, by: \.workspaceID)
        let stickyCounts: [WorkspaceID: Int] = stickiesByWorkspace.mapValues(\.count)
        let sortedWorkspaces = workspaces.sorted { $0.workspaceID.rawValue < $1.workspaceID.rawValue }
        let regions: [CanvasRegionSnapshot] = sortedWorkspaces.compactMap { descriptor in
            guard let origin = layout.workspacePositions[descriptor.workspaceID] else {
                return nil
            }
            let frame = CGRect(origin: origin, size: size)
            let stickyPreviews = makeStickyPreviews(for: stickiesByWorkspace[descriptor.workspaceID] ?? [], size: size)
            return CanvasRegionSnapshot(
                workspaceID: descriptor.workspaceID,
                displayID: descriptor.displayID,
                frame: frame,
                stickyCount: stickyCounts[descriptor.workspaceID, default: 0],
                isActive: descriptor.workspaceID == activeWorkspaceID,
                stickyPreviews: stickyPreviews,
                thumbnail: CanvasThumbnailMetadata(
                    source: .synthetic,
                    displayID: descriptor.displayID
                )
            )
        }

        return CanvasSnapshot(
            viewport: viewport,
            activeWorkspaceID: activeWorkspaceID,
            regions: regions,
            invariants: invariantChecks(regions: regions, activeWorkspaceID: activeWorkspaceID)
        )
    }

    private static func makeStickyPreviews(for notes: [StickyNote], size: CGSize) -> [CanvasStickyPreview] {
        guard !notes.isEmpty else {
            return []
        }

        let maxX = notes.map { $0.position.x + max(1, $0.size.width) }.max() ?? size.width
        let maxY = notes.map { $0.position.y + max(1, $0.size.height) }.max() ?? size.height
        let workspaceWidth = max(1, max(size.width, maxX))
        let workspaceHeight = max(1, max(size.height, maxY))

        return notes
            .sorted { $0.createdAt < $1.createdAt }
            .map { note in
                CanvasStickyPreview(
                    id: note.id,
                    text: note.text,
                    header: note.header,
                    x: Double(note.position.x / workspaceWidth),
                    y: Double(note.position.y / workspaceHeight),
                    width: Double(note.size.width / workspaceWidth),
                    height: Double(note.size.height / workspaceHeight)
                )
            }
    }

    private static func nextDefaultPosition(occupied: [CGPoint], size: CGSize) -> CGPoint {
        var slot = 0
        while true {
            let candidate = point(forSlot: slot, size: size)
            let candidateFrame = CGRect(origin: candidate, size: size)
            if occupied.allSatisfy({ existing in
                let frame = CGRect(origin: existing, size: size)
                return frame.intersects(candidateFrame) == false
            }) {
                return candidate
            }
            slot += 1
        }
    }

    private static func point(forSlot slot: Int, size: CGSize) -> CGPoint {
        let row = slot / columns
        let column = slot % columns
        let x = CGFloat(column) * (size.width + horizontalSpacing)
        let y = CGFloat(row) * (size.height + verticalSpacing)
        return CGPoint(x: x, y: y)
    }

    private static func invariantChecks(
        regions: [CanvasRegionSnapshot],
        activeWorkspaceID: WorkspaceID?
    ) -> [String] {
        var issues: [String] = []
        for i in regions.indices {
            for j in regions.indices where j > i {
                if regions[i].frame.intersects(regions[j].frame) {
                    let lhs = regions[i].workspaceID.rawValue
                    let rhs = regions[j].workspaceID.rawValue
                    issues.append("overlap detected between \(lhs) and \(rhs)")
                }
            }
        }

        if let activeWorkspaceID {
            let activeCount = regions.filter { $0.workspaceID == activeWorkspaceID }.count
            if activeCount != 1 {
                issues.append("active workspace highlight is ambiguous")
            }
        }
        return issues.sorted()
    }
}
