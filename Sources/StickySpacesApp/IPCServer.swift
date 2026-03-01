import CoreGraphics
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
                let created = try await manager.createSticky(text: text ?? "")
                return .created(id: created.sticky.id, workspaceID: created.sticky.workspaceID)
            } catch StickyManagerError.workspaceTransitioning(let details) {
                return .workspaceTransitioning(details)
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("yabai unavailable")
            }
        case .edit(let id, let text):
            do {
                try await manager.updateStickyText(id: id, text: text)
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .dismiss(let id):
            do {
                try await manager.dismissSticky(id: id)
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .dismissAll:
            do {
                try await manager.dismissAllStickiesOnCurrentWorkspace()
                return .ok
            } catch {
                return .error("cannot dismiss-all")
            }
        case .move(let id, let x, let y):
            do {
                try await manager.updateStickyPosition(id: id, x: x, y: y)
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .resize(let id, let width, let height):
            do {
                try await manager.updateStickySize(id: id, width: width, height: height)
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .zoomOut:
            do {
                let snapshot = try await manager.zoomOutSnapshot()
                return .canvasSnapshot(snapshot)
            } catch {
                return .error("cannot zoom-out")
            }
        case .zoomIn(let workspaceID):
            do {
                try await manager.zoomIn(workspaceID: workspaceID)
                return .ok
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("cannot zoom-in")
            }
        case .navigateFromCanvasClick(let stickyID):
            do {
                try await manager.navigateFromCanvasClick(stickyID: stickyID)
                return .ok
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("cannot navigate from canvas")
            }
        case .list(let space):
            let notes = await manager.list(space: space)
            return .stickyList(notes)
        case .get(let id):
            do {
                let note = try await manager.getSticky(id: id)
                return .sticky(note)
            } catch {
                return .error("sticky not found")
            }
        case .canvasLayout:
            do {
                let layout = try await manager.canvasLayout()
                return .canvasLayout(layout)
            } catch {
                return .error("cannot read canvas-layout")
            }
        case .moveRegion(let workspaceID, let x, let y):
            await manager.setWorkspacePosition(workspaceID, position: CGPoint(x: x, y: y))
            return .ok
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
