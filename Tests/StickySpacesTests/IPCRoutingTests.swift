import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesClient
@testable import StickySpacesShared

@Suite("IPC text protocol")
struct IPCRoutingTests {
    @Test("routes new/list over newline-delimited JSON")
    func routesNewListOverTextProtocol() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 3)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let client = StickySpacesClient(
            transport: ClosureTransport { line in
                await server.handleLine(line)
            }
        )

        _ = try await client.new(text: "One")
        let listed = try await client.list(space: nil)

        #expect(listed.count == 1)
        #expect(listed[0].text == "One")
        #expect(listed[0].workspaceID == WorkspaceID(rawValue: 3))
    }
}
