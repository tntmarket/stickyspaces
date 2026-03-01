import Foundation

public enum StickyFocusIntent: String, Codable, Sendable, Equatable {
    case focusTextInputImmediately
}

public struct StickyNote: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var text: String
    public let workspaceID: WorkspaceID
    public let createdAt: Date
    public let focusIntent: StickyFocusIntent

    public init(
        id: UUID = UUID(),
        text: String,
        workspaceID: WorkspaceID,
        createdAt: Date = Date(),
        focusIntent: StickyFocusIntent = .focusTextInputImmediately
    ) {
        self.id = id
        self.text = text
        self.workspaceID = workspaceID
        self.createdAt = createdAt
        self.focusIntent = focusIntent
    }
}
