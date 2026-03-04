import Foundation
import StickySpacesShared

public enum CLIClientRunner {
    public static func run(args: [String], socketPath: String) async throws -> String {
        guard let request = translateArgs(args) else {
            return usage()
        }

        let client: IPCSocketClient
        do {
            client = try IPCSocketClient(socketPath: socketPath)
        } catch is IPCSocketClientError {
            try await DaemonLauncher.ensureDaemonRunning(socketPath: socketPath)
            client = try IPCSocketClient(socketPath: socketPath)
        }
        defer { client.close() }

        let response = try await client.send(request)
        return formatResponse(response, for: request)
    }

    static func translateArgs(_ args: [String]) -> IPCRequest? {
        guard let command = args.first else { return nil }

        switch command {
        case "new":
            return .new(text: parseOption("--text", in: args))
        case "edit":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else { return nil }
            return .edit(id: id, text: parseOption("--text", in: args) ?? "")
        case "dismiss":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else { return nil }
            return .dismiss(id: id)
        case "dismiss-all":
            return .dismissAll
        case "move":
            guard args.count >= 2, let id = UUID(uuidString: args[1]),
                  let x = parseDoubleOption("--x", in: args),
                  let y = parseDoubleOption("--y", in: args)
            else { return nil }
            return .move(id: id, x: x, y: y)
        case "resize":
            guard args.count >= 2, let id = UUID(uuidString: args[1]),
                  let width = parseDoubleOption("--width", in: args),
                  let height = parseDoubleOption("--height", in: args)
            else { return nil }
            return .resize(id: id, width: width, height: height)
        case "zoom-out":
            return .zoomOut
        case "zoom-in":
            guard let rawSpace = parseIntOption("--space", in: args) else { return nil }
            return .zoomIn(space: WorkspaceID(rawValue: rawSpace))
        case "list":
            return .list(space: nil)
        case "get":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else { return nil }
            return .get(id: id)
        case "canvas-layout":
            return .canvasLayout
        case "move-region":
            guard let rawSpace = parseIntOption("--space", in: args),
                  let x = parseDoubleOption("--x", in: args),
                  let y = parseDoubleOption("--y", in: args)
            else { return nil }
            return .moveRegion(space: WorkspaceID(rawValue: rawSpace), x: x, y: y)
        case "status":
            return .status
        case "verify-sync":
            return .verifySync
        default:
            return nil
        }
    }

    static func formatResponse(_ response: IPCResponse, for request: IPCRequest) -> String {
        if case .ok = response {
            return formatOkResponse(for: request)
        }
        switch response {
        case .hello(let serverVersion, let minClient, let capabilities):
            return "hello server-version: \(serverVersion) min-client: \(minClient) capabilities: read-space=\(capabilities.canReadCurrentSpace) list-spaces=\(capabilities.canListSpaces) focus-space=\(capabilities.canFocusSpace) diff-topology=\(capabilities.canDiffTopology)"
        case .protocolMismatch(_, _, let message):
            return "error: \(message)"
        case .created(let id, let workspaceID):
            return "created id: \(id) workspace: \(workspaceID.rawValue)"
        case .ok:
            return "ok"
        case .sticky(let note):
            return "id: \(note.id) workspace: \(note.workspaceID.rawValue) text: \(note.text) position: (\(note.position.x), \(note.position.y)) size: (\(note.size.width), \(note.size.height))"
        case .stickyList(let notes):
            if notes.isEmpty { return "no stickies" }
            return notes
                .map { "\($0.id.uuidString) [space \($0.workspaceID.rawValue)] \($0.text)" }
                .joined(separator: "\n")
        case .canvasLayout(let layout):
            let lines = layout.workspacePositions.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { workspaceID in
                    let point = layout.workspacePositions[workspaceID] ?? .zero
                    let displayID = layout.workspaceDisplayIDs[workspaceID] ?? -1
                    return "workspace \(workspaceID.rawValue) display \(displayID) position (\(point.x),\(point.y))"
                }
            return lines.isEmpty ? "no workspaces" : lines.joined(separator: "\n")
        case .canvasSnapshot(let snapshot):
            let regionSummary = snapshot.regions
                .map { region in
                    let activeFlag = region.isActive ? "*" : "-"
                    let origin = "(\(region.frame.origin.x),\(region.frame.origin.y))"
                    return "\(activeFlag) workspace \(region.workspaceID.rawValue) display \(region.displayID) origin \(origin) stickies \(region.stickyCount)"
                }
                .joined(separator: "\n")
            let active = snapshot.activeWorkspaceID?.rawValue.description ?? "none"
            let invariants = snapshot.invariants.joined(separator: ";")
            return "active-workspace: \(active) zoom: \(snapshot.viewport.zoomScale) pan: (\(snapshot.viewport.panOffset.x),\(snapshot.viewport.panOffset.y)) invariants: [\(invariants)]\n\(regionSummary)"
        case .status(let status):
            return "running: \(status.running) mode: \(status.mode.rawValue) space: \(status.space?.rawValue.description ?? "none") count: \(status.stickyCount) warnings: \(status.warnings.joined(separator: ",")) panel: \(status.panelVisibilityStrategy.rawValue)"
        case .syncResult(let synced, let mismatches):
            return "synced: \(synced) mismatches: \(mismatches.joined(separator: ";"))"
        case .workspaceTransitioning(let info):
            return "workspace transitioning: \(info.message)"
        case .unsupportedMode(let info):
            return "unsupported mode: \(info.reason)"
        case .error(let message):
            return "error: \(message)"
        }
    }

    private static func formatOkResponse(for request: IPCRequest) -> String {
        switch request {
        case .edit(let id, _): return "edited id: \(id)"
        case .dismiss(let id): return "dismissed id: \(id)"
        case .dismissAll: return "dismissed all"
        case .move(let id, _, _): return "moved id: \(id)"
        case .resize(let id, _, _): return "resized id: \(id)"
        case .zoomIn(let space): return "zoomed-in workspace: \(space.rawValue)"
        case .moveRegion(let space, _, _): return "moved region for workspace \(space.rawValue)"
        default: return "ok"
        }
    }

    private static func usage() -> String {
        """
        stickyspaces commands:
          new [--text TEXT]
          edit <id> --text TEXT
          dismiss <id>
          dismiss-all
          move <id> --x X --y Y
          resize <id> --width W --height H
          zoom-out
          zoom-in --space N
          list
          get <id>
          canvas-layout
          move-region --space N --x X --y Y
          status
          verify-sync
        """
    }

    private static func parseOption(_ key: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    private static func parseDoubleOption(_ key: String, in args: [String]) -> Double? {
        guard let raw = parseOption(key, in: args) else { return nil }
        return Double(raw)
    }

    private static func parseIntOption(_ key: String, in args: [String]) -> Int? {
        guard let raw = parseOption(key, in: args) else { return nil }
        return Int(raw)
    }
}
