import Foundation
import StickySpacesShared

public enum YabaiUnavailableError: Error {
    case unavailable
}

public protocol YabaiQuerying: Sendable {
    func currentSpaceID() async throws -> WorkspaceID
}

public struct FakeYabaiQuerying: YabaiQuerying {
    public let currentSpace: WorkspaceID?

    public init(currentSpace: WorkspaceID?) {
        self.currentSpace = currentSpace
    }

    public func currentSpaceID() async throws -> WorkspaceID {
        guard let currentSpace else {
            throw YabaiUnavailableError.unavailable
        }
        return currentSpace
    }
}

public protocol PanelSyncing: Sendable {
    func show(stickyID: UUID, workspaceID: WorkspaceID) async
    func visibleStickyIDs(on workspaceID: WorkspaceID) async -> Set<UUID>
}

public actor InMemoryPanelSync: PanelSyncing {
    private var visibleByWorkspace: [WorkspaceID: Set<UUID>] = [:]

    public init() {}

    public func show(stickyID: UUID, workspaceID: WorkspaceID) async {
        var ids = visibleByWorkspace[workspaceID, default: Set<UUID>()]
        ids.insert(stickyID)
        visibleByWorkspace[workspaceID] = ids
    }

    public func visibleStickyIDs(on workspaceID: WorkspaceID) async -> Set<UUID> {
        visibleByWorkspace[workspaceID, default: Set<UUID>()]
    }
}
