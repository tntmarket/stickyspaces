import CoreGraphics
import Foundation
import StickySpacesShared

public enum CanvasLayoutEngine {
    public static let regionSize = CGSize(width: 480, height: 320)
    private static let horizontalSpacing: CGFloat = 80
    private static let verticalSpacing: CGFloat = 80
    private static let columns = 3

    public static func resolveLayout(
        storedLayout: CanvasLayout,
        workspaces: [WorkspaceDescriptor]
    ) -> CanvasLayout {
        let sortedWorkspaces = workspaces.sorted { $0.workspaceID.rawValue < $1.workspaceID.rawValue }
        var positions = storedLayout.workspacePositions
        var displayIDs = storedLayout.workspaceDisplayIDs

        for descriptor in sortedWorkspaces {
            displayIDs[descriptor.workspaceID] = descriptor.displayID
            if positions[descriptor.workspaceID] == nil {
                positions[descriptor.workspaceID] = nextDefaultPosition(occupied: Array(positions.values))
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
        viewport: CanvasViewportState
    ) -> CanvasSnapshot {
        let stickyCounts: [WorkspaceID: Int] = Dictionary(
            grouping: stickies,
            by: \.workspaceID
        ).reduce(into: [:]) { partialResult, element in
            partialResult[element.key] = element.value.count
        }
        let sortedWorkspaces = workspaces.sorted { $0.workspaceID.rawValue < $1.workspaceID.rawValue }
        let regions: [CanvasRegionSnapshot] = sortedWorkspaces.compactMap { descriptor in
            guard let origin = layout.workspacePositions[descriptor.workspaceID] else {
                return nil
            }
            let frame = CGRect(origin: origin, size: regionSize)
            return CanvasRegionSnapshot(
                workspaceID: descriptor.workspaceID,
                displayID: descriptor.displayID,
                frame: frame,
                stickyCount: stickyCounts[descriptor.workspaceID, default: 0],
                isActive: descriptor.workspaceID == activeWorkspaceID
            )
        }

        return CanvasSnapshot(
            viewport: viewport,
            activeWorkspaceID: activeWorkspaceID,
            regions: regions,
            invariants: invariantChecks(regions: regions, activeWorkspaceID: activeWorkspaceID)
        )
    }

    private static func nextDefaultPosition(occupied: [CGPoint]) -> CGPoint {
        var slot = 0
        while true {
            let candidate = point(forSlot: slot)
            let candidateFrame = CGRect(origin: candidate, size: regionSize)
            if occupied.allSatisfy({ existing in
                let frame = CGRect(origin: existing, size: regionSize)
                return frame.intersects(candidateFrame) == false
            }) {
                return candidate
            }
            slot += 1
        }
    }

    private static func point(forSlot slot: Int) -> CGPoint {
        let row = slot / columns
        let column = slot % columns
        let x = CGFloat(column) * (regionSize.width + horizontalSpacing)
        let y = CGFloat(row) * (regionSize.height + verticalSpacing)
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
