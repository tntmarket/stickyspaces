import Foundation
import StickySpacesShared

public actor StickyStore {
    private var notes: [UUID: StickyNote] = [:]

    public init() {}

    public func createSticky(text: String, workspaceID: WorkspaceID) -> StickyNote {
        let note = StickyNote(text: text, workspaceID: workspaceID)
        notes[note.id] = note
        return note
    }

    public func list(space: WorkspaceID?) -> [StickyNote] {
        notes.values
            .filter { space == nil || $0.workspaceID == space }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func updateText(stickyID: UUID, text: String) -> StickyNote? {
        guard var note = notes[stickyID] else {
            return nil
        }
        note.text = text
        notes[stickyID] = note
        return note
    }

    public func count() -> Int {
        notes.count
    }
}
