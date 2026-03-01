import Foundation
import Testing
@testable import StickySpacesCLI

@Suite("CLI commands")
struct CLITests {
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
}
