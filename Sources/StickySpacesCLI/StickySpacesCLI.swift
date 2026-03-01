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
        case "list":
            let notes = try await app.client.list(space: nil)
            if notes.isEmpty {
                return "no stickies"
            }
            return notes
                .map { "\($0.id.uuidString) [space \($0.workspaceID.rawValue)] \($0.text)" }
                .joined(separator: "\n")
        case "status":
            let status = try await app.client.status()
            return "running: \(status.running) mode: \(status.mode.rawValue) space: \(status.space?.rawValue.description ?? "none") count: \(status.stickyCount) warnings: \(status.warnings.joined(separator: ","))"
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

    private static func usage() -> String {
        """
        stickyspaces commands:
          new [--text TEXT]
          edit <id> --text TEXT
          list
          status
          verify-sync
        """
    }
}
