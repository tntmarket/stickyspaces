import Foundation

public struct StickyNote: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var text: String
    public let workspaceID: WorkspaceID
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        workspaceID: WorkspaceID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.workspaceID = workspaceID
        self.createdAt = createdAt
    }
}
