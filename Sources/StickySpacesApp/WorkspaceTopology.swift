import Foundation
import StickySpacesShared

public struct WorkspaceDescriptor: Sendable, Equatable, Codable {
    public let workspaceID: WorkspaceID
    public let index: Int
    public let displayID: Int

    public init(workspaceID: WorkspaceID, index: Int, displayID: Int) {
        self.workspaceID = workspaceID
        self.index = index
        self.displayID = displayID
    }
}

public struct WorkspaceTopologySnapshot: Sendable, Equatable, Codable {
    public let spaces: [WorkspaceDescriptor]
    public let primaryDisplayID: Int

    public init(spaces: [WorkspaceDescriptor], primaryDisplayID: Int) {
        self.spaces = spaces
        self.primaryDisplayID = primaryDisplayID
    }
}

public enum WorkspaceTopologyHealth: Sendable, Equatable {
    case healthy
    case unhealthy
}

public struct TopologyReconcileResult: Sendable, Equatable {
    public let suspectedRemoved: [WorkspaceID]
    public let confirmedRemoved: [WorkspaceID]

    public init(suspectedRemoved: [WorkspaceID], confirmedRemoved: [WorkspaceID]) {
        self.suspectedRemoved = suspectedRemoved
        self.confirmedRemoved = confirmedRemoved
    }
}

public actor WorkspaceMonitor {
    private var latestSnapshot: WorkspaceTopologySnapshot?

    public init() {}

    public func publish(snapshot: WorkspaceTopologySnapshot) {
        latestSnapshot = snapshot
    }

    public func drainLatest() -> WorkspaceTopologySnapshot? {
        defer { latestSnapshot = nil }
        return latestSnapshot
    }
}

public actor WorkspaceTopologyReconciler {
    private let confirmationInterval: TimeInterval
    private var knownWorkspaces: Set<WorkspaceID> = []
    private var suspectedAt: [WorkspaceID: Date] = [:]

    public init(confirmationInterval: TimeInterval = 2) {
        self.confirmationInterval = confirmationInterval
    }

    public func reconcile(
        snapshot: WorkspaceTopologySnapshot,
        health: WorkspaceTopologyHealth,
        now: Date
    ) -> TopologyReconcileResult {
        let currentIDs = Set(snapshot.spaces.map(\.workspaceID))
        let missing = knownWorkspaces.subtracting(currentIDs)

        // Any workspace seen again is no longer in suspected-removal state.
        for id in currentIDs {
            suspectedAt[id] = nil
        }

        var suspectedRemoved: [WorkspaceID] = []
        var confirmedRemoved: [WorkspaceID] = []
        if health == .healthy {
            for id in missing {
                if let firstMissing = suspectedAt[id] {
                    let elapsed = now.timeIntervalSince(firstMissing)
                    if elapsed >= confirmationInterval {
                        confirmedRemoved.append(id)
                        suspectedAt[id] = nil
                    }
                } else {
                    suspectedAt[id] = now
                    suspectedRemoved.append(id)
                }
            }
        }

        knownWorkspaces = currentIDs.union(missing.subtracting(Set(confirmedRemoved)))
        knownWorkspaces.subtract(Set(confirmedRemoved))

        return TopologyReconcileResult(
            suspectedRemoved: suspectedRemoved.sorted { $0.rawValue < $1.rawValue },
            confirmedRemoved: confirmedRemoved.sorted { $0.rawValue < $1.rawValue }
        )
    }
}
