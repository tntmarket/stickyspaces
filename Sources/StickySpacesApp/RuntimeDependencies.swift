import Foundation
import StickySpacesShared

public enum YabaiUnavailableError: Error {
    case unavailable
}

public enum WorkspaceBinding: Sendable, Equatable {
    case stable(workspaceID: WorkspaceID, displayID: Int, isPrimaryDisplay: Bool)
    case transitioning(retryAfterMilliseconds: Int)
}

public protocol YabaiQuerying: Sendable {
    func currentBinding() async throws -> WorkspaceBinding
    func topologySnapshot() async throws -> WorkspaceTopologySnapshot
    func capabilities() async -> CapabilityState
}

public extension YabaiQuerying {
    func currentSpaceID() async throws -> WorkspaceID {
        let binding = try await currentBinding()
        switch binding {
        case .stable(let workspaceID, _, _):
            return workspaceID
        case .transitioning:
            throw YabaiUnavailableError.unavailable
        }
    }
}

public actor FakeYabaiQuerying: YabaiQuerying {
    private var binding: WorkspaceBinding
    private var snapshot: WorkspaceTopologySnapshot
    private var capabilityState: CapabilityState

    public init(currentSpace: WorkspaceID?) {
        if let currentSpace {
            binding = .stable(workspaceID: currentSpace, displayID: 1, isPrimaryDisplay: true)
            capabilityState = .normal
            snapshot = WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: currentSpace, index: 1, displayID: 1)],
                primaryDisplayID: 1
            )
        } else {
            binding = .transitioning(retryAfterMilliseconds: 250)
            capabilityState = .degraded
            snapshot = WorkspaceTopologySnapshot(spaces: [], primaryDisplayID: 1)
        }
    }

    public func currentBinding() async throws -> WorkspaceBinding {
        if capabilityState.canReadCurrentSpace == false {
            throw YabaiUnavailableError.unavailable
        }
        return binding
    }

    public func topologySnapshot() async throws -> WorkspaceTopologySnapshot {
        if capabilityState.canListSpaces == false {
            throw YabaiUnavailableError.unavailable
        }
        return snapshot
    }

    public func capabilities() async -> CapabilityState {
        capabilityState
    }

    public func setCurrentBinding(_ newBinding: WorkspaceBinding) {
        binding = newBinding
    }

    public func setTopologySnapshot(_ newSnapshot: WorkspaceTopologySnapshot) {
        snapshot = newSnapshot
    }

    public func setCapabilities(_ capabilities: CapabilityState) {
        capabilityState = capabilities
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
