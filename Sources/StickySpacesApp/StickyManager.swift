import CoreGraphics
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

public struct YabaiTimeoutPolicy: Sendable, Equatable {
    public let focusSpaceTimeoutMilliseconds: Int

    public init(focusSpaceTimeoutMilliseconds: Int = 750) {
        self.focusSpaceTimeoutMilliseconds = focusSpaceTimeoutMilliseconds
    }
}

public actor StickyManager {
    private let store: StickyStore
    private let yabai: any YabaiQuerying
    private let panelSync: any PanelSyncing
    private let topologyReconciler: WorkspaceTopologyReconciler
    private let transitionProfile: ZoomTransitionProfile
    private let timeoutPolicy: YabaiTimeoutPolicy

    public init(
        store: StickyStore,
        yabai: any YabaiQuerying,
        panelSync: any PanelSyncing,
        topologyReconciler: WorkspaceTopologyReconciler = WorkspaceTopologyReconciler(),
        transitionProfile: ZoomTransitionProfile = .phase0Selected,
        timeoutPolicy: YabaiTimeoutPolicy = YabaiTimeoutPolicy()
    ) {
        self.store = store
        self.yabai = yabai
        self.panelSync = panelSync
        self.topologyReconciler = topologyReconciler
        self.transitionProfile = transitionProfile
        self.timeoutPolicy = timeoutPolicy
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

    public func setWorkspacePosition(_ workspaceID: WorkspaceID, position: CGPoint) async {
        await store.setWorkspacePosition(workspaceID, position: position)
    }

    public func canvasLayout() async throws -> CanvasLayout {
        let topology = try await yabai.topologySnapshot()
        return await resolvedCanvasLayout(for: topology)
    }

    public func zoomOutSnapshot(
        viewport: CanvasViewportState = .defaultOverview
    ) async throws -> CanvasSnapshot {
        let topology = try await yabai.topologySnapshot()
        let layout = await resolvedCanvasLayout(for: topology)
        let stickies = await store.list(space: nil)
        let activeWorkspaceID = try? await yabai.currentSpaceID()

        return CanvasLayoutEngine.makeSnapshot(
            layout: layout,
            workspaces: topology.spaces,
            stickies: stickies,
            activeWorkspaceID: activeWorkspaceID,
            viewport: viewport
        )
    }

    public func zoomIn(workspaceID: WorkspaceID) async throws {
        _ = try await performZoomIn(workspaceID: workspaceID, forcedMode: nil)
    }

    public func simulateZoomTransitionRoundTrip(
        targetWorkspaceID: WorkspaceID,
        forcedMode: ZoomTransitionMode? = nil
    ) async throws -> ZoomTransitionMetrics {
        _ = try await zoomOutSnapshot()
        return try await performZoomIn(workspaceID: targetWorkspaceID, forcedMode: forcedMode)
    }

    public func verifyForcedModeParity(targetWorkspaceID: WorkspaceID) async throws -> ZoomTransitionParityResult {
        guard transitionProfile.dualModeEnabled else {
            let metrics = try await simulateZoomTransitionRoundTrip(targetWorkspaceID: targetWorkspaceID)
            return ZoomTransitionParityResult(
                passed: metrics.durationMilliseconds >= 300 && metrics.durationMilliseconds <= 500,
                metricsByMode: [metrics.mode: metrics]
            )
        }

        let originSpace = try? await yabai.currentSpaceID()
        var byMode: [ZoomTransitionMode: ZoomTransitionMetrics] = [:]
        for mode in ZoomTransitionMode.allCases {
            let metrics = try await simulateZoomTransitionRoundTrip(
                targetWorkspaceID: targetWorkspaceID,
                forcedMode: mode
            )
            byMode[mode] = metrics
            if let originSpace {
                try? await yabai.focusSpace(originSpace)
            }
        }
        let passed = byMode.values.allSatisfy { metric in
            metric.durationMilliseconds >= 300 && metric.durationMilliseconds <= 500
        }
        return ZoomTransitionParityResult(passed: passed, metricsByMode: byMode)
    }

    private func performZoomIn(
        workspaceID: WorkspaceID,
        forcedMode: ZoomTransitionMode?
    ) async throws -> ZoomTransitionMetrics {
        let capabilities = await yabai.capabilities()
        guard capabilities.canFocusSpace else {
            throw StickyManagerError.unsupportedMode(
                UnsupportedModeResponse(
                    command: "zoom-in",
                    mode: .degraded,
                    reason: "focus-space capability unavailable",
                    warnings: ["yabai cannot focus spaces"]
                )
            )
        }
        let mode = try resolveTransitionMode(forcedMode: forcedMode)
        let focusResult = await withBoundedTimeout(milliseconds: timeoutPolicy.focusSpaceTimeoutMilliseconds) {
            try await self.yabai.focusSpace(workspaceID)
        }
        switch focusResult {
        case .success:
            break
        case .timedOut:
            await yabai.markTimeout(for: .focusSpace)
            throw StickyManagerError.unsupportedMode(
                UnsupportedModeResponse(
                    command: "zoom-in",
                    mode: .degraded,
                    reason: "focus-space timed out",
                    warnings: ["focus-space capability downgraded after timeout"]
                )
            )
        case .failure:
            throw StickyManagerError.unsupportedMode(
                UnsupportedModeResponse(
                    command: "zoom-in",
                    mode: .degraded,
                    reason: "focus-space unavailable",
                    warnings: ["yabai cannot focus spaces"]
                )
            )
        }
        let usedLivenessFallback = try await waitForZoomInCompletion(targetWorkspaceID: workspaceID)
        let duration = ZoomTransitionDurationModel.durationMilliseconds(
            mode: mode,
            usedLivenessFallback: usedLivenessFallback
        )
        return ZoomTransitionMetrics(
            mode: mode,
            durationMilliseconds: duration,
            usedLivenessFallback: usedLivenessFallback
        )
    }

    private func resolveTransitionMode(forcedMode: ZoomTransitionMode?) throws -> ZoomTransitionMode {
        guard let forcedMode else {
            return transitionProfile.selectedMode
        }
        if forcedMode != transitionProfile.selectedMode && !transitionProfile.dualModeEnabled {
            throw StickyManagerError.unsupportedMode(
                UnsupportedModeResponse(
                    command: "zoom-transition",
                    mode: .normal,
                    reason: "forced-mode parity requires dual-mode support",
                    warnings: []
                )
            )
        }
        return forcedMode
    }

    private func waitForZoomInCompletion(targetWorkspaceID: WorkspaceID) async throws -> Bool {
        var usedLivenessFallback = false
        for _ in 0..<4 {
            if try await isCurrentWorkspace(targetWorkspaceID) {
                return usedLivenessFallback
            }
            usedLivenessFallback = true
        }

        // Lost notifications can happen in the wild; bounded polling + refocus keeps liveness deterministic.
        try await yabai.focusSpace(targetWorkspaceID)
        for _ in 0..<2 {
            if try await isCurrentWorkspace(targetWorkspaceID) {
                return true
            }
        }

        throw StickyManagerError.workspaceTransitioning(
            WorkspaceTransitioningResponse(
                retriable: true,
                retryAfterMilliseconds: 100,
                message: "zoom-in did not converge within bounded liveness window"
            )
        )
    }

    private func isCurrentWorkspace(_ workspaceID: WorkspaceID) async throws -> Bool {
        let binding = try await yabai.currentBinding()
        guard case .stable(let currentWorkspaceID, _, _) = binding else {
            return false
        }
        return currentWorkspaceID == workspaceID
    }

    public func navigateFromCanvasClick(stickyID: UUID) async throws {
        guard let sticky = await store.sticky(id: stickyID) else {
            throw StickyManagerError.stickyNotFound(stickyID)
        }
        try await zoomIn(workspaceID: sticky.workspaceID)
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
        return await verifySync(space: currentSpace)
    }

    public func verifySync(space: WorkspaceID) async -> VerifySyncResult {
        let expected = Set(await store.list(space: space).map(\.id))
        let visible = await panelSync.visibleStickyIDs(on: space)
        let missing = expected.subtracting(visible)
        let mismatches = missing.map { "sticky \($0) is missing panel on workspace \(space.rawValue)" }
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

    private func resolvedCanvasLayout(for topology: WorkspaceTopologySnapshot) async -> CanvasLayout {
        let existingLayout = await store.canvasLayout()
        let resolved = CanvasLayoutEngine.resolveLayout(
            storedLayout: existingLayout,
            workspaces: topology.spaces
        )
        await store.setCanvasLayout(resolved)
        return resolved
    }

    private func runtimeProjection() async -> (
        space: WorkspaceID?,
        mode: RuntimeMode,
        warnings: [String],
        panelVisibilityStrategy: PanelVisibilityStrategy
    ) {
        let capabilities = await yabai.capabilities()
        let strategy: PanelVisibilityStrategy = capabilities.canDiffTopology ? .automaticPrimary : .manualFallback
        var warnings: [String] = []
        if capabilities.canReadCurrentSpace == false { warnings.append("yabai current-space capability unavailable") }
        if capabilities.canListSpaces == false { warnings.append("yabai list-spaces capability unavailable") }
        if capabilities.canFocusSpace == false { warnings.append("yabai focus-space capability unavailable") }
        if capabilities.canDiffTopology == false { warnings.append("yabai topology-diff capability unavailable") }
        let hasCapabilityDegradation = warnings.isEmpty == false

        if capabilities.canReadCurrentSpace == false {
            var degradedWarnings = warnings
            if degradedWarnings.contains("yabai unavailable") == false {
                degradedWarnings.insert("yabai unavailable", at: 0)
            }
            return (nil, .degraded, degradedWarnings, strategy)
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
            return (currentSpace, .degraded, warnings.isEmpty ? ["cannot list spaces"] : warnings, strategy)
        }

        let displayIDs = Set(topology.spaces.map(\.displayID))
        if displayIDs.count > 1 {
            let warning = "single-display mode: binding to primary display \(topology.primaryDisplayID)"
            return (currentSpace, .singleDisplay, [warning] + warnings, strategy)
        }

        if hasCapabilityDegradation {
            return (currentSpace, .degraded, warnings, strategy)
        }

        return (currentSpace, .normal, [], strategy)
    }

    private enum TimeoutResult {
        case success
        case timedOut
        case failure
    }

    private func withBoundedTimeout(
        milliseconds: Int,
        operation: @escaping @Sendable () async throws -> Void
    ) async -> TimeoutResult {
        await withTaskGroup(of: TimeoutResult.self) { group in
            group.addTask {
                do {
                    try await operation()
                    return .success
                } catch {
                    return .failure
                }
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(max(1, milliseconds)))
                return .timedOut
            }
            let result = await group.next() ?? .failure
            group.cancelAll()
            return result
        }
    }
}
