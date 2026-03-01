import Foundation
import StickySpacesShared

public protocol IPCTransport: Sendable {
    func send(line: String) async throws -> String
}

public struct ClosureTransport: IPCTransport {
    private let handler: @Sendable (String) async throws -> String

    public init(handler: @escaping @Sendable (String) async throws -> String) {
        self.handler = handler
    }

    public func send(line: String) async throws -> String {
        try await handler(line)
    }
}

public enum StickySpacesClientError: Error {
    case unexpectedResponse(String)
    case serverError(String)
}

public struct StickySpacesClient: Sendable {
    private let transport: any IPCTransport

    public init(transport: any IPCTransport) {
        self.transport = transport
    }

    public func new(text: String?) async throws -> (id: UUID, workspaceID: WorkspaceID) {
        let response = try await send(.new(text: text))
        if case .created(let id, let workspaceID) = response {
            return (id, workspaceID)
        }
        return try throwResponseError(response)
    }

    public func list(space: WorkspaceID?) async throws -> [StickyNote] {
        let response = try await send(.list(space: space))
        if case .stickyList(let notes) = response {
            return notes
        }
        return try throwResponseError(response)
    }

    public func status() async throws -> StatusSnapshot {
        let response = try await send(.status)
        if case .status(let status) = response {
            return status
        }
        return try throwResponseError(response)
    }

    public func verifySync() async throws -> VerifySyncResult {
        let response = try await send(.verifySync)
        if case .syncResult(let synced, let mismatches) = response {
            return VerifySyncResult(synced: synced, mismatches: mismatches)
        }
        return try throwResponseError(response)
    }

    public func handshake(protocolVersion: Int) async throws -> IPCResponse {
        try await send(.hello(protocolVersion: protocolVersion))
    }

    private func send(_ request: IPCRequest) async throws -> IPCResponse {
        let requestLine = try IPCWireCodec.encodeRequestLine(request)
        let responseLine = try await transport.send(line: requestLine)
        return try IPCWireCodec.decodeResponseLine(responseLine)
    }

    private func throwResponseError<T>(_ response: IPCResponse) throws -> T {
        if case .error(let message) = response {
            throw StickySpacesClientError.serverError(message)
        }
        throw StickySpacesClientError.unexpectedResponse(String(describing: response))
    }
}
