import Foundation
import StickySpacesApp
import StickySpacesClient
import StickySpacesShared

public struct DemoApp {
    public let automation: any StickySpacesAutomating
    public let client: StickySpacesClient

    public init(automation: any StickySpacesAutomating, client: StickySpacesClient) {
        self.automation = automation
        self.client = client
    }
}

public enum DemoAppFactory {
    public static func makeReady(workspaceID: WorkspaceID = WorkspaceID(rawValue: 1)) -> DemoApp {
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspaceID),
            panelSync: panelSync
        )
        let automation = StickySpacesAutomationAPI(manager: manager, panelSync: panelSync)
        let server = IPCServer(manager: manager)
        let transport = ClosureTransport { line in
            await server.handleLine(line)
        }
        return DemoApp(
            automation: automation,
            client: StickySpacesClient(transport: transport)
        )
    }

    public static func makeWithUnavailableYabai() -> DemoApp {
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: nil),
            panelSync: panelSync
        )
        let automation = StickySpacesAutomationAPI(manager: manager, panelSync: panelSync)
        let server = IPCServer(manager: manager)
        let transport = ClosureTransport { line in
            await server.handleLine(line)
        }
        return DemoApp(
            automation: automation,
            client: StickySpacesClient(transport: transport)
        )
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
            let created = try await createSticky(text: text, automation: app.automation)
            return "created id: \(created.sticky.id) workspace: \(created.sticky.workspaceID.rawValue)"
        case "edit":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces edit <id> --text TEXT"
            }
            let text = parseOption("--text", in: args) ?? ""
            _ = try await app.automation.perform(.editSticky(id: id, text: text))
            return "edited id: \(id)"
        case "dismiss":
            guard args.count >= 2, let id = UUID(uuidString: args[1]) else {
                return "usage: stickyspaces dismiss <id>"
            }
            _ = try await app.automation.perform(.dismissSticky(id: id))
            return "dismissed id: \(id)"
        case "dismiss-all":
            _ = try await app.automation.perform(.dismissAllCurrentWorkspace)
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
            _ = try await app.automation.perform(.moveSticky(id: id, x: x, y: y))
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
            _ = try await app.automation.perform(.resizeSticky(id: id, width: width, height: height))
            return "resized id: \(id)"
        case "zoom-out":
            let snapshot = try await zoomOutSnapshot(automation: app.automation)
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
            _ = try await app.automation.perform(.zoomIn(workspaceID: WorkspaceID(rawValue: rawSpace)))
            return "zoomed-in workspace: \(rawSpace)"
        case "list":
            let notes = try await listStickies(space: nil, automation: app.automation)
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
            let note = try await getSticky(id: id, automation: app.automation)
            return "id: \(note.id) workspace: \(note.workspaceID.rawValue) text: \(note.text) position: (\(note.position.x), \(note.position.y)) size: (\(note.size.width), \(note.size.height))"
        case "canvas-layout":
            let layout = try await canvasLayout(automation: app.automation)
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
            _ = try await app.automation.perform(
                .moveWorkspaceRegion(
                    workspaceID: WorkspaceID(rawValue: rawSpace),
                    x: x,
                    y: y
                )
            )
            return "moved region for workspace \(rawSpace)"
        case "status":
            let status = try await runtimeStatus(automation: app.automation)
            return "running: \(status.running) mode: \(status.mode.rawValue) space: \(status.space?.rawValue.description ?? "none") count: \(status.stickyCount) warnings: \(status.warnings.joined(separator: ",")) panel: \(status.panelVisibilityStrategy.rawValue)"
        case "verify-sync":
            let result = try await verifySync(automation: app.automation)
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

    private static func createSticky(
        text: String?,
        automation: any StickySpacesAutomating
    ) async throws -> StickyCreateResult {
        let response = try await automation.perform(.createSticky(text: text))
        guard case .created(let created) = response else {
            throw CLICommandError.unexpectedResponse(command: "new", response: response)
        }
        return created
    }

    private static func listStickies(
        space: WorkspaceID?,
        automation: any StickySpacesAutomating
    ) async throws -> [StickyNote] {
        let response = try await automation.perform(.listStickies(space: space))
        guard case .stickyList(let notes) = response else {
            throw CLICommandError.unexpectedResponse(command: "list", response: response)
        }
        return notes
    }

    private static func getSticky(
        id: UUID,
        automation: any StickySpacesAutomating
    ) async throws -> StickyNote {
        let response = try await automation.perform(.getSticky(id: id))
        guard case .sticky(let note) = response else {
            throw CLICommandError.unexpectedResponse(command: "get", response: response)
        }
        return note
    }

    private static func zoomOutSnapshot(
        automation: any StickySpacesAutomating
    ) async throws -> CanvasSnapshot {
        let response = try await automation.perform(.zoomOutSnapshot)
        guard case .canvasSnapshot(let snapshot) = response else {
            throw CLICommandError.unexpectedResponse(command: "zoom-out", response: response)
        }
        return snapshot
    }

    private static func canvasLayout(
        automation: any StickySpacesAutomating
    ) async throws -> CanvasLayout {
        let response = try await automation.perform(.canvasLayout)
        guard case .canvasLayout(let layout) = response else {
            throw CLICommandError.unexpectedResponse(command: "canvas-layout", response: response)
        }
        return layout
    }

    private static func runtimeStatus(
        automation: any StickySpacesAutomating
    ) async throws -> StatusSnapshot {
        let response = try await automation.perform(.status)
        guard case .status(let status) = response else {
            throw CLICommandError.unexpectedResponse(command: "status", response: response)
        }
        return status
    }

    private static func verifySync(
        automation: any StickySpacesAutomating
    ) async throws -> VerifySyncResult {
        let response = try await automation.perform(.verifySync)
        guard case .verifySync(let result) = response else {
            throw CLICommandError.unexpectedResponse(command: "verify-sync", response: response)
        }
        return result
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

private enum CLICommandError: Error {
    case unexpectedResponse(command: String, response: StickySpacesAutomationResponse)
}
