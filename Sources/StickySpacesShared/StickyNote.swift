import Foundation
import CoreGraphics

public enum StickyFocusIntent: String, Codable, Sendable, Equatable {
    case focusTextInputImmediately
}

public struct StickyNote: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var text: String
    public var position: CGPoint
    public var size: CGSize
    public let workspaceID: WorkspaceID
    public let createdAt: Date
    public let focusIntent: StickyFocusIntent

    public init(
        id: UUID = UUID(),
        text: String,
        position: CGPoint = CGPoint(x: 80, y: 80),
        size: CGSize = CGSize(width: 320, height: 220),
        workspaceID: WorkspaceID,
        createdAt: Date = Date(),
        focusIntent: StickyFocusIntent = .focusTextInputImmediately
    ) {
        self.id = id
        self.text = text
        self.position = position
        self.size = size
        self.workspaceID = workspaceID
        self.createdAt = createdAt
        self.focusIntent = focusIntent
    }
}
