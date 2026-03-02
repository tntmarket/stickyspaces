import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("CLI workflows from a user perspective")
struct CLIWorkflowTests {
    @Test("user runs status and the CLI forwards the parsed command to automation")
    func userRunsStatusAndCliForwardsCommandToAutomation() async throws {
        let spy = AutomationSpy(
            responses: [
                .status(
                    StatusSnapshot(
                        running: true,
                        space: WorkspaceID(rawValue: 1),
                        stickyCount: 2,
                        mode: .normal,
                        warnings: [],
                        panelVisibilityStrategy: .automaticPrimary
                    )
                )
            ]
        )
        let app = DemoApp(automation: spy)

        let output = try await StickySpacesCLICommandRunner.run(args: ["status"], app: app)

        #expect(output.contains("mode: normal"))
        #expect(output.contains("count: 2"))
        #expect(await spy.recordedCommands() == [.status])
    }

    @Test("user creates a sticky then sees it in list, status, and verify-sync output")
    func userCreatesStickyThenSeesItAcrossListStatusAndVerifySync() async throws {
        let app = DemoAppFactory.makeReady()

        let newOutput = try await StickySpacesCLICommandRunner.run(
            args: ["new", "--text", "Hello"],
            app: app
        )
        #expect(newOutput.contains("created"))

        let listOutput = try await StickySpacesCLICommandRunner.run(
            args: ["list"],
            app: app
        )
        #expect(listOutput.contains("Hello"))

        let statusOutput = try await StickySpacesCLICommandRunner.run(
            args: ["status"],
            app: app
        )
        #expect(statusOutput.contains("mode: normal"))

        let verifyOutput = try await StickySpacesCLICommandRunner.run(
            args: ["verify-sync"],
            app: app
        )
        #expect(verifyOutput.contains("synced: true"))
    }

    @Test("user edits a sticky and sees updated text in list output")
    func userEditsStickyAndSeesUpdatedTextInListOutput() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await createSticky(text: "Before", app: app)

        let editOutput = try await StickySpacesCLICommandRunner.run(
            args: ["edit", created.sticky.id.uuidString, "--text", "After"],
            app: app
        )
        #expect(editOutput.contains("edited"))

        let listOutput = try await StickySpacesCLICommandRunner.run(
            args: ["list"],
            app: app
        )
        #expect(listOutput.contains("After"))
    }

    @Test("user moves a sticky and get shows the new position")
    func userMovesStickyAndGetShowsUpdatedPosition() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await createSticky(text: "Move me", app: app)

        let moveOutput = try await StickySpacesCLICommandRunner.run(
            args: ["move", created.sticky.id.uuidString, "--x", "101.25", "--y", "202.5"],
            app: app
        )
        #expect(moveOutput.contains("moved"))

        let getOutput = try await StickySpacesCLICommandRunner.run(
            args: ["get", created.sticky.id.uuidString],
            app: app
        )
        #expect(getOutput.contains("position: (101.25, 202.5)"))
    }

    @Test("user resizes a sticky and get shows deterministic dimensions")
    func userResizesStickyAndGetShowsDeterministicDimensions() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await createSticky(text: "Resize me", app: app)

        let resizeOutput = try await StickySpacesCLICommandRunner.run(
            args: ["resize", created.sticky.id.uuidString, "--width", "333.75", "--height", "222.5"],
            app: app
        )
        #expect(resizeOutput.contains("resized"))

        let getOutput = try await StickySpacesCLICommandRunner.run(
            args: ["get", created.sticky.id.uuidString],
            app: app
        )
        #expect(getOutput.contains("size: (333.75, 222.5)"))
    }

    @Test("user dismisses one sticky and then clears the remaining stickies")
    func userDismissesOneStickyAndThenDismissesRemainingStickies() async throws {
        let app = DemoAppFactory.makeReady()
        let first = try await createSticky(text: "One", app: app)
        _ = try await createSticky(text: "Two", app: app)
        _ = try await createSticky(text: "Three", app: app)

        let dismissOutput = try await StickySpacesCLICommandRunner.run(
            args: ["dismiss", first.sticky.id.uuidString],
            app: app
        )
        #expect(dismissOutput.contains("dismissed"))

        let listAfterDismiss = try await StickySpacesCLICommandRunner.run(
            args: ["list"],
            app: app
        )
        #expect(listAfterDismiss.contains("One") == false)
        #expect(listAfterDismiss.contains("Two"))
        #expect(listAfterDismiss.contains("Three"))

        let dismissAllOutput = try await StickySpacesCLICommandRunner.run(
            args: ["dismiss-all"],
            app: app
        )
        #expect(dismissAllOutput.contains("dismissed all"))

        let listAfterDismissAll = try await StickySpacesCLICommandRunner.run(
            args: ["list"],
            app: app
        )
        #expect(listAfterDismissAll == "no stickies")
    }

    @Test("user zooms out twice and receives deterministic canvas snapshot metadata")
    func userZoomsOutTwiceAndReceivesDeterministicCanvasSnapshotMetadata() async throws {
        let app = DemoAppFactory.makeReady()
        _ = try await createSticky(text: "One", app: app)

        let first = try await StickySpacesCLICommandRunner.run(
            args: ["zoom-out"],
            app: app
        )
        let second = try await StickySpacesCLICommandRunner.run(
            args: ["zoom-out"],
            app: app
        )

        #expect(first.contains("active-workspace"))
        #expect(first == second)
    }

    @Test("user zooms out and sees canvas context in output")
    func userZoomsOutAndSeesCanvasContextInOutput() async throws {
        let app = DemoAppFactory.makeReady()
        _ = try await createSticky(text: "One", app: app)

        let output = try await StickySpacesCLICommandRunner.run(
            args: ["zoom-out"],
            app: app
        )

        #expect(output.contains("active-workspace"))
        #expect(output.contains("workspace"))
    }

    @Test("user requests canvas layout and sees workspace display positions")
    func userRequestsCanvasLayoutAndSeesWorkspaceDisplayPositions() async throws {
        let app = DemoAppFactory.makeReady()
        let output = try await StickySpacesCLICommandRunner.run(
            args: ["canvas-layout"],
            app: app
        )

        #expect(output.contains("workspace"))
        #expect(output.contains("display"))
    }

    @Test("user moves a region and canvas layout persists across repeated reads")
    func userMovesRegionAndCanvasLayoutPersistsAcrossRepeatedReads() async throws {
        let app = DemoAppFactory.makeReady()

        let moveRegionOutput = try await StickySpacesCLICommandRunner.run(
            args: ["move-region", "--space", "1", "--x", "640", "--y", "320"],
            app: app
        )
        #expect(moveRegionOutput.contains("moved region"))

        let first = try await StickySpacesCLICommandRunner.run(
            args: ["canvas-layout"],
            app: app
        )
        let second = try await StickySpacesCLICommandRunner.run(
            args: ["canvas-layout"],
            app: app
        )

        #expect(first.contains("workspace 1"))
        #expect(first.contains("(640.0,320.0)"))
        #expect(first == second)
    }

    private func createSticky(text: String, app: DemoApp) async throws -> StickyCreateResult {
        let response = try await app.automation.perform(.createSticky(text: text))
        guard case .created(let created) = response else {
            throw NSError(
                domain: "CLIWorkflowTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "expected createSticky to return .created"]
            )
        }
        return created
    }
}

private actor AutomationSpy: StickySpacesAutomating {
    private var responses: [StickySpacesAutomationResponse]
    private var commands: [StickySpacesAutomationCommand] = []

    init(responses: [StickySpacesAutomationResponse]) {
        self.responses = responses
    }

    func perform(_ command: StickySpacesAutomationCommand) async throws -> StickySpacesAutomationResponse {
        commands.append(command)
        if responses.isEmpty {
            return .ok
        }
        return responses.removeFirst()
    }

    func beginScenarioActions(_ scenarioID: String) async {}

    func completeScenarioActions(_ scenarioID: String) async {}

    func recordedCommands() -> [StickySpacesAutomationCommand] {
        commands
    }
}
