import Foundation
import CoreGraphics
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

    public func updatePosition(stickyID: UUID, x: Double, y: Double) -> StickyNote? {
        guard var note = notes[stickyID] else {
            return nil
        }
        note.position = CGPoint(x: x, y: y)
        notes[stickyID] = note
        return note
    }

    public func updateSize(stickyID: UUID, width: Double, height: Double) -> StickyNote? {
        guard var note = notes[stickyID] else {
            return nil
        }
        note.size = CGSize(width: width, height: height)
        notes[stickyID] = note
        return note
    }

    public func sticky(id: UUID) -> StickyNote? {
        notes[id]
    }

    public func count() -> Int {
        notes.count
    }

    public func deleteSticky(id: UUID) -> StickyNote? {
        notes.removeValue(forKey: id)
    }

    public func deleteAll(in workspaceID: WorkspaceID) {
        notes = notes.filter { $0.value.workspaceID != workspaceID }
    }
}
