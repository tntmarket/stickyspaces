import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Session scope contracts (C-3)")
struct SessionScopeContractsTests {
    @Test("new app session starts with empty in-memory sticky state")
    func newAppSessionStartsWithEmptyInMemoryStickyState() async throws {
        let firstSession = DemoAppFactory.makeReady()
        _ = try await createStickyResult(text: "session scoped", app: firstSession)
        let firstList = try await listStickies(app: firstSession)
        #expect(firstList.count == 1)

        let secondSession = DemoAppFactory.makeReady()
        let secondList = try await listStickies(app: secondSession)
        #expect(secondList.isEmpty)
    }

    private func createStickyResult(text: String, app: DemoApp) async throws -> StickyCreateResult {
        let response = try await app.automation.perform(.createSticky(text: text))
        guard case .created(let created) = response else {
            throw NSError(
                domain: "SessionScopeContractsTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "expected createSticky to return .created"]
            )
        }
        return created
    }

    private func listStickies(app: DemoApp) async throws -> [StickyNote] {
        let response = try await app.automation.perform(.listStickies(space: nil))
        guard case .stickyList(let notes) = response else {
            throw NSError(
                domain: "SessionScopeContractsTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "expected listStickies to return .stickyList"]
            )
        }
        return notes
    }
}
