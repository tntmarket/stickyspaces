import Foundation
import StickySpacesShared

public enum StickyManagerError: Error {
    case stickyNotFound(UUID)
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

    public init(
        store: StickyStore,
        yabai: any YabaiQuerying,
        panelSync: any PanelSyncing
    ) {
        self.store = store
        self.yabai = yabai
        self.panelSync = panelSync
    }

    public func createSticky(text: String) async throws -> StickyCreateResult {
        let workspaceID = try await yabai.currentSpaceID()
        let note = await store.createSticky(text: text, workspaceID: workspaceID)
        await panelSync.show(stickyID: note.id, workspaceID: workspaceID)
        return StickyCreateResult(sticky: note, focusIntent: note.focusIntent)
    }

    public func updateStickyText(id: UUID, text: String) async throws {
        let updated = await store.updateText(stickyID: id, text: text)
        guard updated != nil else {
            throw StickyManagerError.stickyNotFound(id)
        }
    }

    public func list(space: WorkspaceID?) async -> [StickyNote] {
        await store.list(space: space)
    }

    public func status() async -> StatusSnapshot {
        do {
            let space = try await yabai.currentSpaceID()
            let stickyCount = await store.count()
            return StatusSnapshot(
                running: true,
                space: space,
                stickyCount: stickyCount,
                mode: .normal,
                warnings: []
            )
        } catch {
            let stickyCount = await store.count()
            return StatusSnapshot(
                running: true,
                space: nil,
                stickyCount: stickyCount,
                mode: .degraded,
                warnings: ["yabai unavailable"]
            )
        }
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
        do {
            _ = try await yabai.currentSpaceID()
            return .normal
        } catch {
            return .degraded
        }
    }
}
