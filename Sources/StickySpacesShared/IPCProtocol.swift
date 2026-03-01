import Foundation

public enum IPCRequest: Codable, Sendable, Equatable {
    case hello(protocolVersion: Int)
    case new(text: String?)
    case edit(id: UUID, text: String)
    case list(space: WorkspaceID?)
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
    case stickyList([StickyNote])
    case status(StatusSnapshot)
    case syncResult(synced: Bool, mismatches: [String])
    case error(String)
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
