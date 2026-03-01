import Foundation

public enum RuntimeMode: String, Codable, Sendable {
    case normal
    case singleDisplay
    case degraded
}

public enum PanelVisibilityStrategy: String, Codable, Sendable, Equatable {
    case automaticPrimary
    case manualFallback
}

public struct CapabilityState: Codable, Sendable, Equatable {
    public let canReadCurrentSpace: Bool
    public let canListSpaces: Bool
    public let canFocusSpace: Bool
    public let canDiffTopology: Bool

    public init(
        canReadCurrentSpace: Bool,
        canListSpaces: Bool,
        canFocusSpace: Bool,
        canDiffTopology: Bool
    ) {
        self.canReadCurrentSpace = canReadCurrentSpace
        self.canListSpaces = canListSpaces
        self.canFocusSpace = canFocusSpace
        self.canDiffTopology = canDiffTopology
    }

    public static let degraded = CapabilityState(
        canReadCurrentSpace: false,
        canListSpaces: false,
        canFocusSpace: false,
        canDiffTopology: false
    )

    public static let normal = CapabilityState(
        canReadCurrentSpace: true,
        canListSpaces: true,
        canFocusSpace: true,
        canDiffTopology: true
    )
}

public struct StatusSnapshot: Codable, Sendable, Equatable {
    public let running: Bool
    public let space: WorkspaceID?
    public let stickyCount: Int
    public let mode: RuntimeMode
    public let warnings: [String]
    public let panelVisibilityStrategy: PanelVisibilityStrategy

    public init(
        running: Bool,
        space: WorkspaceID?,
        stickyCount: Int,
        mode: RuntimeMode,
        warnings: [String],
        panelVisibilityStrategy: PanelVisibilityStrategy
    ) {
        self.running = running
        self.space = space
        self.stickyCount = stickyCount
        self.mode = mode
        self.warnings = warnings
        self.panelVisibilityStrategy = panelVisibilityStrategy
    }
}

public struct VerifySyncResult: Codable, Sendable, Equatable {
    public let synced: Bool
    public let mismatches: [String]

    public init(synced: Bool, mismatches: [String]) {
        self.synced = synced
        self.mismatches = mismatches
    }
}
