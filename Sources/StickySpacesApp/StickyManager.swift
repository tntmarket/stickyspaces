import Foundation
import StickySpacesShared

public enum StickyManagerError: Error {
    case stickyNotFound(UUID)
    case workspaceTransitioning(WorkspaceTransitioningResponse)
    case unsupportedMode(UnsupportedModeResponse)
}

public struct StickyCreateResult: Sendable, Equatable {
    public let sticky: StickyNote
    public let focusIntent: StickyFocusIntent

    public init(sticky: StickyNote, focusIntent: StickyFocusIntent) {
        self.sticky = sticky
        self.focusIntent = focusIntent
    }
}

public actor StickyManager {
    private let store: StickyStore
    private let yabai: any YabaiQuerying
    private let panelSync: any PanelSyncing
    private let topologyReconciler: WorkspaceTopologyReconciler

    public init(
        store: StickyStore,
        yabai: any YabaiQuerying,
        panelSync: any PanelSyncing,
        topologyReconciler: WorkspaceTopologyReconciler = WorkspaceTopologyReconciler()
    ) {
        self.store = store
        self.yabai = yabai
        self.panelSync = panelSync
        self.topologyReconciler = topologyReconciler
    }

    public func createSticky(text: String) async throws -> StickyCreateResult {
        let binding = try await yabai.currentBinding()
        switch binding {
        case .transitioning(let retryAfterMilliseconds):
            throw StickyManagerError.workspaceTransitioning(
                WorkspaceTransitioningResponse(
                    retriable: true,
                    retryAfterMilliseconds: retryAfterMilliseconds,
                    message: "workspace is transitioning; retry"
                )
            )
        case .stable(let workspaceID, _, let isPrimaryDisplay):
            let runtime = await runtimeProjection()
            if runtime.mode == .singleDisplay && !isPrimaryDisplay {
                throw StickyManagerError.unsupportedMode(
                    UnsupportedModeResponse(
                        command: "new",
                        mode: runtime.mode,
                        reason: "command from non-primary display",
                        warnings: runtime.warnings
                    )
                )
            }

            let note = await store.createSticky(text: text, workspaceID: workspaceID)
            await panelSync.show(stickyID: note.id, workspaceID: workspaceID)
            return StickyCreateResult(sticky: note, focusIntent: note.focusIntent)
        }
    }

    public func updateStickyText(id: UUID, text: String) async throws {
        let updated = await store.updateText(stickyID: id, text: text)
        guard updated != nil else {
            throw StickyManagerError.stickyNotFound(id)
        }
    }

    public func updateStickyPosition(id: UUID, x: Double, y: Double) async throws {
        let updated = await store.updatePosition(stickyID: id, x: x, y: y)
        guard updated != nil else {
            throw StickyManagerError.stickyNotFound(id)
        }
    }

    public func updateStickySize(id: UUID, width: Double, height: Double) async throws {
        let updated = await store.updateSize(stickyID: id, width: width, height: height)
        guard updated != nil else {
            throw StickyManagerError.stickyNotFound(id)
        }
    }

    public func getSticky(id: UUID) async throws -> StickyNote {
        guard let note = await store.sticky(id: id) else {
            throw StickyManagerError.stickyNotFound(id)
        }
        return note
    }

    public func dismissSticky(id: UUID) async throws {
        guard let removed = await store.deleteSticky(id: id) else {
            throw StickyManagerError.stickyNotFound(id)
        }
        await panelSync.hide(stickyID: removed.id, workspaceID: removed.workspaceID)
    }

    public func dismissAllStickiesOnCurrentWorkspace() async throws {
        let workspaceID = try await yabai.currentSpaceID()
        await store.deleteAll(in: workspaceID)
        await panelSync.hideAll(on: workspaceID)
    }

    public func list(space: WorkspaceID?) async -> [StickyNote] {
        await store.list(space: space)
    }

    public func status() async -> StatusSnapshot {
        let stickyCount = await store.count()
        let runtime = await runtimeProjection()

        return StatusSnapshot(
            running: true,
            space: runtime.space,
            stickyCount: stickyCount,
            mode: runtime.mode,
            warnings: runtime.warnings,
            panelVisibilityStrategy: runtime.panelVisibilityStrategy
        )
    }

    public func verifySync() async throws -> VerifySyncResult {
        let currentSpace = try await yabai.currentSpaceID()
        let expected = Set(await store.list(space: currentSpace).map(\.id))
        let visible = await panelSync.visibleStickyIDs(on: currentSpace)
        let missing = expected.subtracting(visible)
        let mismatches = missing.map { "sticky \($0) is missing panel on workspace \(currentSpace.rawValue)" }
        return VerifySyncResult(synced: mismatches.isEmpty, mismatches: mismatches.sorted())
    }

    public func capabilities() async -> CapabilityState {
        await yabai.capabilities()
    }

    public func reconcileTopology(
        snapshot: WorkspaceTopologySnapshot,
        health: WorkspaceTopologyHealth,
        now: Date
    ) async -> TopologyReconcileResult {
        let result = await topologyReconciler.reconcile(snapshot: snapshot, health: health, now: now)
        for workspaceID in result.confirmedRemoved {
            await store.deleteAll(in: workspaceID)
        }
        return result
    }

    private func runtimeProjection() async -> (
        space: WorkspaceID?,
        mode: RuntimeMode,
        warnings: [String],
        panelVisibilityStrategy: PanelVisibilityStrategy
    ) {
        let capabilities = await yabai.capabilities()
        let strategy: PanelVisibilityStrategy = capabilities.canDiffTopology ? .automaticPrimary : .manualFallback
        if capabilities.canReadCurrentSpace == false {
            return (nil, .degraded, ["yabai unavailable"], strategy)
        }

        let binding = try? await yabai.currentBinding()
        let currentSpace: WorkspaceID?
        switch binding {
        case .stable(let workspaceID, _, _):
            currentSpace = workspaceID
        default:
            currentSpace = nil
        }

        guard let topology = try? await yabai.topologySnapshot() else {
            return (currentSpace, .degraded, ["cannot list spaces"], strategy)
        }

        let displayIDs = Set(topology.spaces.map(\.displayID))
        if displayIDs.count > 1 {
            let warning = "single-display mode: binding to primary display \(topology.primaryDisplayID)"
            return (currentSpace, .singleDisplay, [warning], strategy)
        }

        return (currentSpace, .normal, [], strategy)
    }
}
