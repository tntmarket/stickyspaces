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

        let created = try await manager.createSticky(text: "Hello")
        let sticky = created.sticky

        #expect(sticky.workspaceID == workspace)
        #expect(sticky.focusIntent == .focusTextInputImmediately)
        #expect(created.focusIntent == .focusTextInputImmediately)
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

    @Test("test_updateStickyText")
    func test_updateStickyText() async throws {
        let workspace = WorkspaceID(rawValue: 7)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )
        let created = try await manager.createSticky(text: "Before")

        try await manager.updateStickyText(id: created.sticky.id, text: "After")
        let notes = await manager.list(space: workspace)

        #expect(notes.count == 1)
        #expect(notes[0].text == "After")
    }
}
