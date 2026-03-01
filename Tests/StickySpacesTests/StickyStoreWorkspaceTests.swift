import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Sticky creation workspace binding")
struct StickyStoreWorkspaceTests {
    @Test("test_createSticky_associatesWithCurrentWorkspace")
    func test_createSticky_associatesWithCurrentWorkspace() async throws {
        let workspace = WorkspaceID(rawValue: 42)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )

        let sticky = try await manager.createSticky(text: "Hello")

        #expect(sticky.workspaceID == workspace)
    }

    @Test("test_createSticky_appearsOnCurrentWorkspace")
    func test_createSticky_appearsOnCurrentWorkspace() async throws {
        let workspace = WorkspaceID(rawValue: 9)
        let panelSync = InMemoryPanelSync()
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: panelSync
        )

        _ = try await manager.createSticky(text: "Visible")
        let result = try await manager.verifySync()

        #expect(result.synced)
        #expect(result.mismatches.isEmpty)
    }
}
