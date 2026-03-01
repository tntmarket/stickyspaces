import Foundation
import StickySpacesApp
import StickySpacesClient
import StickySpacesShared

public struct DemoApp {
    public let client: StickySpacesClient

    public init(client: StickySpacesClient) {
        self.client = client
    }
}

public enum DemoAppFactory {
    public static func makeReady(workspaceID: WorkspaceID = WorkspaceID(rawValue: 1)) -> DemoApp {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspaceID),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let transport = ClosureTransport { line in
            await server.handleLine(line)
        }
        return DemoApp(client: StickySpacesClient(transport: transport))
    }

    public static func makeWithUnavailableYabai() -> DemoApp {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: nil),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let transport = ClosureTransport { line in
            await server.handleLine(line)
        }
        return DemoApp(client: StickySpacesClient(transport: transport))
    }
}

public enum StickySpacesCLICommandRunner {
    public static func run(args: [String], app: DemoApp) async throws -> String {
        guard let command = args.first else {
            return usage()
        }

        switch command {
        case "new":
            let text = parseOption("--text", in: args)
            let created = try await app.client.new(text: text)
            return "created id: \(created.id) workspace: \(created.workspaceID.rawValue)"
        case "edit":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces edit <id> --text TEXT"
            }
            let text = parseOption("--text", in: args) ?? ""
            try await app.client.edit(id: id, text: text)
            return "edited id: \(id)"
        case "dismiss":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces dismiss <id>"
            }
            try await app.client.dismiss(id: id)
            return "dismissed id: \(id)"
        case "dismiss-all":
            try await app.client.dismissAll()
            return "dismissed all"
        case "move":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces move <id> --x X --y Y"
            }
            guard
                let x = parseDoubleOption("--x", in: args),
                let y = parseDoubleOption("--y", in: args)
            else {
                return "usage: stickyspaces move <id> --x X --y Y"
            }
            try await app.client.move(id: id, x: x, y: y)
            return "moved id: \(id)"
        case "resize":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces resize <id> --width W --height H"
            }
            guard
                let width = parseDoubleOption("--width", in: args),
                let height = parseDoubleOption("--height", in: args)
            else {
                return "usage: stickyspaces resize <id> --width W --height H"
            }
            try await app.client.resize(id: id, width: width, height: height)
            return "resized id: \(id)"
        case "zoom-out":
            let snapshot = try await app.client.zoomOut()
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
        case "zoom-in":
            guard let rawSpace = parseIntOption("--space", in: args) else {
                return "usage: stickyspaces zoom-in --space N"
            }
            try await app.client.zoomIn(space: WorkspaceID(rawValue: rawSpace))
            return "zoomed-in workspace: \(rawSpace)"
        case "list":
            let notes = try await app.client.list(space: nil)
            if notes.isEmpty {
                return "no stickies"
            }
            return notes
                .map { "\($0.id.uuidString) [space \($0.workspaceID.rawValue)] \($0.text)" }
                .joined(separator: "\n")
        case "get":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces get <id>"
            }
            let note = try await app.client.get(id: id)
            return "id: \(note.id) workspace: \(note.workspaceID.rawValue) text: \(note.text) position: (\(note.position.x), \(note.position.y)) size: (\(note.size.width), \(note.size.height))"
        case "canvas-layout":
            let layout = try await app.client.canvasLayout()
            let lines = layout.workspacePositions.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { workspaceID in
                    let point = layout.workspacePositions[workspaceID] ?? .zero
                    let displayID = layout.workspaceDisplayIDs[workspaceID] ?? -1
                    return "workspace \(workspaceID.rawValue) display \(displayID) position (\(point.x),\(point.y))"
                }
            return lines.isEmpty ? "no workspaces" : lines.joined(separator: "\n")
        case "move-region":
            guard
                let rawSpace = parseIntOption("--space", in: args),
                let x = parseDoubleOption("--x", in: args),
                let y = parseDoubleOption("--y", in: args)
            else {
                return "usage: stickyspaces move-region --space N --x X --y Y"
            }
            try await app.client.moveRegion(space: WorkspaceID(rawValue: rawSpace), x: x, y: y)
            return "moved region for workspace \(rawSpace)"
        case "status":
            let status = try await app.client.status()
            return "running: \(status.running) mode: \(status.mode.rawValue) space: \(status.space?.rawValue.description ?? "none") count: \(status.stickyCount) warnings: \(status.warnings.joined(separator: ",")) panel: \(status.panelVisibilityStrategy.rawValue)"
        case "verify-sync":
            let result = try await app.client.verifySync()
            return "synced: \(result.synced) mismatches: \(result.mismatches.joined(separator: ";"))"
        default:
            return usage()
        }
    }

    private static func parseOption(_ key: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: key), index + 1 < args.count else {
            return nil
        }
        return args[index + 1]
    }

    private static func parseDoubleOption(_ key: String, in args: [String]) -> Double? {
        guard let raw = parseOption(key, in: args) else {
            return nil
        }
        return Double(raw)
    }

    private static func parseIntOption(_ key: String, in args: [String]) -> Int? {
        guard let raw = parseOption(key, in: args) else {
            return nil
        }
        return Int(raw)
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
}
