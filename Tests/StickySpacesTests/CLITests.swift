import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesClient
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("CLI commands")
struct CLITests {
    @Test("CLI delegates parsed command to canonical automation API")
    func cliDelegatesParsedCommandToCanonicalAutomationAPI() async throws {
        let spy = SpyAutomation(
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
        let app = DemoApp(
            automation: spy,
            client: StickySpacesClient(
                transport: ClosureTransport { _ in
                    throw StickySpacesClientError.serverError("client transport should not be used")
                }
            )
        )

        let output = try await StickySpacesCLICommandRunner.run(args: ["status"], app: app)

        #expect(output.contains("mode: normal"))
        #expect(await spy.recordedCommands() == [.status])
    }

    @Test("new, list, status, verify-sync return useful output")
    func newListStatusVerifySync() async throws {
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

    @Test("test_editSticky_updatesText")
    func test_editSticky_updatesText() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await app.client.new(text: "Before")

        let editOutput = try await StickySpacesCLICommandRunner.run(
            args: ["edit", created.id.uuidString, "--text", "After"],
            app: app
        )
        #expect(editOutput.contains("edited"))

        let listOutput = try await StickySpacesCLICommandRunner.run(
            args: ["list"],
            app: app
        )
        #expect(listOutput.contains("After"))
    }

    @Test("test_moveSticky_updatesPosition")
    func test_moveSticky_updatesPosition() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await app.client.new(text: "Move me")

        let moveOutput = try await StickySpacesCLICommandRunner.run(
            args: ["move", created.id.uuidString, "--x", "101.25", "--y", "202.5"],
            app: app
        )
        #expect(moveOutput.contains("moved"))

        let getOutput = try await StickySpacesCLICommandRunner.run(
            args: ["get", created.id.uuidString],
            app: app
        )
        #expect(getOutput.contains("position: (101.25, 202.5)"))
    }

    @Test("resize and get round-trip deterministic values")
    func resizeAndGetRoundTripDeterministicValues() async throws {
        let app = DemoAppFactory.makeReady()
        let created = try await app.client.new(text: "Resize me")

        let resizeOutput = try await StickySpacesCLICommandRunner.run(
            args: ["resize", created.id.uuidString, "--width", "333.75", "--height", "222.5"],
            app: app
        )
        #expect(resizeOutput.contains("resized"))

        let getOutput = try await StickySpacesCLICommandRunner.run(
            args: ["get", created.id.uuidString],
            app: app
        )
        #expect(getOutput.contains("size: (333.75, 222.5)"))
    }

    @Test("dismiss removes single sticky and dismiss-all clears remainder")
    func dismissAndDismissAllCommands() async throws {
        let app = DemoAppFactory.makeReady()
        let first = try await app.client.new(text: "One")
        _ = try await app.client.new(text: "Two")
        _ = try await app.client.new(text: "Three")

        let dismissOutput = try await StickySpacesCLICommandRunner.run(
            args: ["dismiss", first.id.uuidString],
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

    @Test("zoom-out returns deterministic canvas snapshot metadata")
    func zoomOutReturnsDeterministicSnapshotMetadata() async throws {
        let app = DemoAppFactory.makeReady()
        _ = try await app.client.new(text: "One")

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

    @Test("test_zoomOut_showsCanvas")
    func test_zoomOut_showsCanvas() async throws {
        let app = DemoAppFactory.makeReady()
        _ = try await app.client.new(text: "One")

        let output = try await StickySpacesCLICommandRunner.run(
            args: ["zoom-out"],
            app: app
        )

        #expect(output.contains("active-workspace"))
        #expect(output.contains("workspace"))
    }

    @Test("canvas-layout prints persisted workspace positions")
    func canvasLayoutPrintsPersistedWorkspacePositions() async throws {
        let app = DemoAppFactory.makeReady()
        let output = try await StickySpacesCLICommandRunner.run(
            args: ["canvas-layout"],
            app: app
        )

        #expect(output.contains("workspace"))
        #expect(output.contains("display"))
    }

    @Test("test_canvasArrangementPersists")
    func test_canvasArrangementPersists() async throws {
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
}

private actor SpyAutomation: StickySpacesAutomating {
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
