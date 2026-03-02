import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Sticky notes stay tied to their workspace")
struct StickyWorkspaceBehaviorTests {
    @Test("Creating a sticky binds it to the current workspace")
    func creatingStickyBindsItToCurrentWorkspace() async throws {
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

    @Test("New sticky appears on the current workspace")
    func newStickyAppearsOnCurrentWorkspace() async throws {
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

    @Test("Multiple stickies created in one workspace stay grouped")
    func creatingMultipleStickiesKeepsWorkspaceGrouping() async throws {
        let workspace = WorkspaceID(rawValue: 12)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )

        _ = try await manager.createSticky(text: "One")
        _ = try await manager.createSticky(text: "Two")
        _ = try await manager.createSticky(text: "Three")
        let notes = await manager.list(space: workspace)

        #expect(notes.count == 3)
        #expect(Set(notes.map(\.workspaceID)) == [workspace])
    }

    @Test("Dismissing a sticky removes it from the workspace")
    func dismissingStickyRemovesItFromWorkspace() async throws {
        let workspace = WorkspaceID(rawValue: 12)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )

        let first = try await manager.createSticky(text: "One")
        _ = try await manager.createSticky(text: "Two")
        _ = try await manager.createSticky(text: "Three")

        try await manager.dismissSticky(id: first.sticky.id)
        let notes = await manager.list(space: workspace)

        #expect(notes.count == 2)
        #expect(notes.contains(where: { $0.id == first.sticky.id }) == false)
    }

    @Test("Editing sticky text updates the stored note")
    func editingStickyTextUpdatesStoredNote() async throws {
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

    @Test("Moving a sticky persists its position")
    func movingStickyPersistsPosition() async throws {
        let workspace = WorkspaceID(rawValue: 7)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )
        let created = try await manager.createSticky(text: "Movable")

        try await manager.updateStickyPosition(
            id: created.sticky.id,
            x: 123.5,
            y: 456.25
        )
        let notes = await manager.list(space: workspace)

        #expect(notes.count == 1)
        #expect(notes[0].position.x == 123.5)
        #expect(notes[0].position.y == 456.25)
    }

    @Test("Resizing a sticky persists its size")
    func resizingStickyPersistsSize() async throws {
        let workspace = WorkspaceID(rawValue: 7)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: workspace),
            panelSync: InMemoryPanelSync()
        )
        let created = try await manager.createSticky(text: "Resizable")

        try await manager.updateStickySize(
            id: created.sticky.id,
            width: 333.75,
            height: 222.5
        )
        let notes = await manager.list(space: workspace)

        #expect(notes.count == 1)
        #expect(notes[0].size.width == 333.75)
        #expect(notes[0].size.height == 222.5)
    }
}
