import CoreGraphics
import Foundation
import StickySpacesShared

public enum StickySpacesAutomationCommand: Sendable, Equatable {
    case createSticky(text: String?)
    case editSticky(id: UUID, text: String)
    case dismissSticky(id: UUID)
    case dismissAllCurrentWorkspace
    case moveSticky(id: UUID, x: Double, y: Double)
    case resizeSticky(id: UUID, width: Double, height: Double)
    case zoomOutSnapshot
    case prepareZoomOutOverview
    case animatePreparedZoomOutOverview
    case presentZoomOutOverview
    case zoomIn(workspaceID: WorkspaceID)
    case navigateFromCanvasClick(stickyID: UUID)
    case listStickies(space: WorkspaceID?)
    case getSticky(id: UUID)
    case canvasLayout
    case moveWorkspaceRegion(workspaceID: WorkspaceID, x: Double, y: Double)
    case status
    case verifySync
}

public enum StickySpacesAutomationResponse: Sendable, Equatable {
    case created(StickyCreateResult)
    case sticky(StickyNote)
    case stickyList([StickyNote])
    case canvasLayout(CanvasLayout)
    case canvasSnapshot(CanvasSnapshot)
    case status(StatusSnapshot)
    case verifySync(VerifySyncResult)
    case ok
}

public struct StickySpacesAutomationLifecycleSink: Sendable {
    private let emitBlock: @Sendable (AutomationLifecycleEvent) -> Void

    public init(_ emitBlock: @escaping @Sendable (AutomationLifecycleEvent) -> Void) {
        self.emitBlock = emitBlock
    }

    public func emit(_ event: AutomationLifecycleEvent) {
        emitBlock(event)
    }
}

public protocol StickySpacesAutomating: Sendable {
    func perform(_ command: StickySpacesAutomationCommand) async throws -> StickySpacesAutomationResponse
    func beginScenarioActions(_ scenarioID: String) async
    func completeScenarioActions(_ scenarioID: String) async
}

public actor StickySpacesAutomationAPI: StickySpacesAutomating {
    private let manager: StickyManager
    private let panelSync: (any PanelSyncing)?
    private let zoomOutPresenter: any ZoomOutOverviewPresenting
    private let lifecycleSink: StickySpacesAutomationLifecycleSink?

    public init(
        manager: StickyManager,
        panelSync: (any PanelSyncing)? = nil,
        zoomOutPresenter: any ZoomOutOverviewPresenting = NoopZoomOutOverviewPresenter(),
        lifecycleSink: StickySpacesAutomationLifecycleSink? = nil
    ) {
        self.manager = manager
        self.panelSync = panelSync
        self.zoomOutPresenter = zoomOutPresenter
        self.lifecycleSink = lifecycleSink
    }

    public func beginScenarioActions(_ scenarioID: String) async {
        lifecycleSink?.emit(
            AutomationLifecycleEvent(
                phase: .scenarioActionsStart,
                scenarioID: scenarioID
            )
        )
    }

    public func completeScenarioActions(_ scenarioID: String) async {
        lifecycleSink?.emit(
            AutomationLifecycleEvent(
                phase: .scenarioActionsComplete,
                scenarioID: scenarioID
            )
        )
    }

    public func perform(_ command: StickySpacesAutomationCommand) async throws -> StickySpacesAutomationResponse {
        switch command {
        case .createSticky(let text):
            let created = try await manager.createSticky(text: text ?? "")
            return .created(created)
        case .editSticky(let id, let text):
            try await manager.updateStickyText(id: id, text: text)
            return .ok
        case .dismissSticky(let id):
            try await manager.dismissSticky(id: id)
            return .ok
        case .dismissAllCurrentWorkspace:
            try await manager.dismissAllStickiesOnCurrentWorkspace()
            return .ok
        case .moveSticky(let id, let x, let y):
            try await manager.updateStickyPosition(id: id, x: x, y: y)
            return .ok
        case .resizeSticky(let id, let width, let height):
            try await manager.updateStickySize(id: id, width: width, height: height)
            return .ok
        case .zoomOutSnapshot:
            return .canvasSnapshot(try await manager.zoomOutSnapshot())
        case .prepareZoomOutOverview:
            return try await prepareZoomOutOverview()
        case .animatePreparedZoomOutOverview:
            return await animatePreparedZoomOutOverview()
        case .presentZoomOutOverview:
            return try await presentZoomOutOverview()
        case .zoomIn(let workspaceID):
            try await manager.zoomIn(workspaceID: workspaceID)
            return .ok
        case .navigateFromCanvasClick(let stickyID):
            try await manager.navigateFromCanvasClick(stickyID: stickyID)
            return .ok
        case .listStickies(let space):
            return .stickyList(await manager.list(space: space))
        case .getSticky(let id):
            return .sticky(try await manager.getSticky(id: id))
        case .canvasLayout:
            return .canvasLayout(try await manager.canvasLayout())
        case .moveWorkspaceRegion(let workspaceID, let x, let y):
            await manager.setWorkspacePosition(workspaceID, position: CGPoint(x: x, y: y))
            return .ok
        case .status:
            return .status(await manager.status())
        case .verifySync:
            return .verifySync(try await manager.verifySync())
        }
    }

    private func presentZoomOutOverview() async throws -> StickySpacesAutomationResponse {
        let prepared = try await prepareZoomOutOverview()
        _ = await animatePreparedZoomOutOverview()
        return prepared
    }

    private func prepareZoomOutOverview() async throws -> StickySpacesAutomationResponse {
        let snapshot = try await manager.zoomOutSnapshot()
        let notes = await manager.list(space: nil)
        let heroSticky = pickHeroSticky(notes: notes, activeWorkspaceID: snapshot.activeWorkspaceID)
        await hideVisiblePanels(notes: notes)
        await zoomOutPresenter.preparePresentation(snapshot: snapshot, heroSticky: heroSticky)
        return .canvasSnapshot(snapshot)
    }

    private func animatePreparedZoomOutOverview() async -> StickySpacesAutomationResponse {
        await zoomOutPresenter.animatePreparedPresentation()
        return .ok
    }

    private func hideVisiblePanels(notes: [StickyNote]) async {
        guard let panelSync else {
            return
        }
        for note in notes {
            await panelSync.hide(stickyID: note.id, workspaceID: note.workspaceID)
        }
    }

    private func pickHeroSticky(notes: [StickyNote], activeWorkspaceID: WorkspaceID?) -> StickyNote? {
        guard let activeWorkspaceID else {
            return notes.sorted { $0.createdAt < $1.createdAt }.last
        }
        let activeNotes = notes
            .filter { $0.workspaceID == activeWorkspaceID }
            .sorted { $0.createdAt < $1.createdAt }
        return activeNotes.last ?? notes.sorted { $0.createdAt < $1.createdAt }.last
    }
}

public actor StickySpacesAutomationDebugAPI {
    private let manager: StickyManager
    private let panelSync: any PanelSyncing
    private let yabai: FakeYabaiQuerying

    public init(manager: StickyManager, panelSync: any PanelSyncing, yabai: FakeYabaiQuerying) {
        self.manager = manager
        self.panelSync = panelSync
        self.yabai = yabai
    }

    public func setTopologySnapshot(_ snapshot: WorkspaceTopologySnapshot) async {
        await yabai.setTopologySnapshot(snapshot)
    }

    public func setCurrentBinding(_ binding: WorkspaceBinding) async {
        await yabai.setCurrentBinding(binding)
    }

    public func showOnlyWorkspace(_ workspaceID: WorkspaceID) async {
        let all = await manager.list(space: nil)
        for sticky in all {
            if sticky.workspaceID == workspaceID {
                await panelSync.show(sticky: sticky)
            } else {
                await panelSync.hide(stickyID: sticky.id, workspaceID: sticky.workspaceID)
            }
        }
    }

    public func hideSticky(stickyID: UUID, workspaceID: WorkspaceID) async {
        await panelSync.hide(stickyID: stickyID, workspaceID: workspaceID)
    }

    public func reconcileTopology(
        snapshot: WorkspaceTopologySnapshot,
        health: WorkspaceTopologyHealth,
        now: Date
    ) async -> TopologyReconcileResult {
        await manager.reconcileTopology(snapshot: snapshot, health: health, now: now)
    }

    public func hideAllVisiblePanels() async {
        let all = await manager.list(space: nil)
        for sticky in all {
            await panelSync.hide(stickyID: sticky.id, workspaceID: sticky.workspaceID)
        }
    }
}
