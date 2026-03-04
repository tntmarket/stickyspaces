import Foundation
import StickySpacesShared

public actor IPCServer {
    public static let protocolVersion = 1
    public static let minSupportedClientVersion = 0

    private let manager: StickyManager
    private let automation: StickySpacesAutomationAPI

    public init(manager: StickyManager, automation: StickySpacesAutomationAPI? = nil) {
        self.manager = manager
        self.automation = automation ?? StickySpacesAutomationAPI(manager: manager)
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
                let response = try await automation.perform(.createSticky(text: text))
                guard case .created(let created) = response else {
                    return .error("cannot create sticky")
                }
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
                _ = try await automation.perform(.editSticky(id: id, text: text))
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .dismiss(let id):
            do {
                _ = try await automation.perform(.dismissSticky(id: id))
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .dismissAll:
            do {
                _ = try await automation.perform(.dismissAllCurrentWorkspace)
                return .ok
            } catch {
                return .error("cannot dismiss-all")
            }
        case .move(let id, let x, let y):
            do {
                _ = try await automation.perform(.moveSticky(id: id, x: x, y: y))
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .resize(let id, let width, let height):
            do {
                _ = try await automation.perform(.resizeSticky(id: id, width: width, height: height))
                return .ok
            } catch {
                return .error("sticky not found")
            }
        case .zoomOut:
            do {
                let response = try await automation.perform(.zoomOutSnapshot)
                guard case .canvasSnapshot(let snapshot) = response else {
                    return .error("cannot zoom-out")
                }
                return .canvasSnapshot(snapshot)
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("cannot zoom-out")
            }
        case .zoomIn(let workspaceID):
            do {
                _ = try await automation.perform(.zoomIn(workspaceID: workspaceID))
                return .ok
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("cannot zoom-in")
            }
        case .navigateFromCanvasClick(let stickyID):
            do {
                _ = try await automation.perform(.navigateFromCanvasClick(stickyID: stickyID))
                return .ok
            } catch StickyManagerError.unsupportedMode(let details) {
                return .unsupportedMode(details)
            } catch {
                return .error("cannot navigate from canvas")
            }
        case .list(let space):
            do {
                let response = try await automation.perform(.listStickies(space: space))
                guard case .stickyList(let notes) = response else {
                    return .error("cannot list stickies")
                }
                return .stickyList(notes)
            } catch {
                return .error("cannot list stickies")
            }
        case .get(let id):
            do {
                let response = try await automation.perform(.getSticky(id: id))
                guard case .sticky(let note) = response else {
                    return .error("sticky not found")
                }
                return .sticky(note)
            } catch {
                return .error("sticky not found")
            }
        case .canvasLayout:
            do {
                let response = try await automation.perform(.canvasLayout)
                guard case .canvasLayout(let layout) = response else {
                    return .error("cannot read canvas-layout")
                }
                return .canvasLayout(layout)
            } catch {
                return .error("cannot read canvas-layout")
            }
        case .moveRegion(let workspaceID, let x, let y):
            do {
                _ = try await automation.perform(.moveWorkspaceRegion(workspaceID: workspaceID, x: x, y: y))
                return .ok
            } catch {
                return .error("cannot move region")
            }
        case .status:
            do {
                let response = try await automation.perform(.status)
                guard case .status(let snapshot) = response else {
                    return .error("cannot read status")
                }
                return .status(snapshot)
            } catch {
                return .error("cannot read status")
            }
        case .verifySync:
            do {
                let response = try await automation.perform(.verifySync)
                guard case .verifySync(let sync) = response else {
                    return .error("cannot verify-sync")
                }
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
