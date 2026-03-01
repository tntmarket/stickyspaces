import Foundation

public struct WorkspaceID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
