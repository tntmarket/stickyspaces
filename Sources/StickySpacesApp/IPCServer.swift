import Foundation
import StickySpacesShared

public actor IPCServer {
    public static let protocolVersion = 1
    public static let minSupportedClientVersion = 0

    private let manager: StickyManager

    public init(manager: StickyManager) {
        self.manager = manager
    }

    public func handleLine(_ line: String) async -> String {
        do {
            let request = try IPCWireCodec.decodeRequestLine(line)
            let response = await route(request)
            return (try? IPCWireCodec.encodeResponseLine(response)) ?? "{\"error\":\"encode failed\"}\n"
        } catch {
            let response = IPCResponse.error("invalid request")
            return (try? IPCWireCodec.encodeResponseLine(response)) ?? "{\"error\":\"encode failed\"}\n"
        }
    }

    private func route(_ request: IPCRequest) async -> IPCResponse {
        switch request {
        case .hello(let protocolVersion):
            let minVersion = Self.minSupportedClientVersion
            let maxVersion = Self.protocolVersion
            if protocolVersion > maxVersion || protocolVersion < minVersion {
                return .protocolMismatch(
                    serverProtocolVersion: maxVersion,
                    minSupportedClientVersion: minVersion,
                    message: "Unsupported client protocol version \(protocolVersion)"
                )
            }
            let capabilities = await manager.capabilities()
            return .hello(
                serverProtocolVersion: maxVersion,
                minSupportedClientVersion: minVersion,
                capabilities: capabilities
            )
        case .new(let text):
            do {
                let sticky = try await manager.createSticky(text: text ?? "")
                return .created(id: sticky.id, workspaceID: sticky.workspaceID)
            } catch {
                return .error("yabai unavailable")
            }
        case .list(let space):
            let notes = await manager.list(space: space)
            return .stickyList(notes)
        case .status:
            let snapshot = await manager.status()
            return .status(snapshot)
        case .verifySync:
            do {
                let sync = try await manager.verifySync()
                return .syncResult(synced: sync.synced, mismatches: sync.mismatches)
            } catch {
                return .syncResult(
                    synced: false,
                    mismatches: ["cannot verify-sync: yabai unavailable"]
                )
            }
        }
    }
}
