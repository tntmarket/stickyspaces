import Foundation

public enum IPCRequest: Codable, Sendable, Equatable {
    case hello(protocolVersion: Int)
    case new(text: String?)
    case edit(id: UUID, text: String)
    case move(id: UUID, x: Double, y: Double)
    case resize(id: UUID, width: Double, height: Double)
    case list(space: WorkspaceID?)
    case get(id: UUID)
    case status
    case verifySync
}

public enum IPCResponse: Codable, Sendable, Equatable {
    case hello(
        serverProtocolVersion: Int,
        minSupportedClientVersion: Int,
        capabilities: CapabilityState
    )
    case protocolMismatch(
        serverProtocolVersion: Int,
        minSupportedClientVersion: Int,
        message: String
    )
    case created(id: UUID, workspaceID: WorkspaceID)
    case ok
    case sticky(StickyNote)
    case stickyList([StickyNote])
    case status(StatusSnapshot)
    case syncResult(synced: Bool, mismatches: [String])
    case workspaceTransitioning(WorkspaceTransitioningResponse)
    case unsupportedMode(UnsupportedModeResponse)
    case error(String)
}

public struct WorkspaceTransitioningResponse: Codable, Sendable, Equatable {
    public let retriable: Bool
    public let retryAfterMilliseconds: Int
    public let message: String

    public init(retriable: Bool, retryAfterMilliseconds: Int, message: String) {
        self.retriable = retriable
        self.retryAfterMilliseconds = retryAfterMilliseconds
        self.message = message
    }
}

public struct UnsupportedModeResponse: Codable, Sendable, Equatable {
    public let command: String
    public let mode: RuntimeMode
    public let reason: String
    public let warnings: [String]

    public init(command: String, mode: RuntimeMode, reason: String, warnings: [String]) {
        self.command = command
        self.mode = mode
        self.reason = reason
        self.warnings = warnings
    }
}

public enum IPCWireCodec {
    public static func encodeRequestLine(_ request: IPCRequest) throws -> String {
        try encodeLine(request)
    }

    public static func decodeRequestLine(_ line: String) throws -> IPCRequest {
        try decodeLine(line)
    }

    public static func encodeResponseLine(_ response: IPCResponse) throws -> String {
        try encodeLine(response)
    }

    public static func decodeResponseLine(_ line: String) throws -> IPCResponse {
        try decodeLine(line)
    }

    private static func encodeLine<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard var string = String(data: data, encoding: .utf8) else {
            throw IPCWireError.invalidUTF8
        }
        if !string.hasSuffix("\n") {
            string += "\n"
        }
        return string
    }

    private static func decodeLine<T: Decodable>(_ line: String) throws -> T {
        let cleanLine = line.trimmingCharacters(in: .newlines)
        guard let data = cleanLine.data(using: .utf8) else {
            throw IPCWireError.invalidUTF8
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum IPCWireError: Error {
    case invalidUTF8
}
