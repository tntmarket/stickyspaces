import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Compatibility contracts (C-7, NFR-7)")
struct CompatibilityContractsTests {
    @Test("headless prerequisite diagnostics are actionable")
    func headlessPrerequisiteDiagnosticsAreActionable() {
        let diagnostics = OperationalPrerequisiteDiagnostics.evaluate(
            environment: .init(
                accessibilityTrusted: false,
                yabaiReachable: false,
                keyboardMaestroWired: false
            ),
            context: .headless
        )

        #expect(diagnostics.status == .degraded)
        #expect(diagnostics.items.count == 3)
        #expect(diagnostics.items.allSatisfy { $0.state == .actionRequired })
        #expect(diagnostics.items.contains { $0.message.contains("Accessibility") })
        #expect(diagnostics.items.contains { $0.message.contains("yabai") })
        #expect(diagnostics.items.contains { $0.message.contains("Keyboard Maestro") })
    }

    @Test("protocol version mismatch returns a clear compatibility envelope")
    func protocolVersionMismatchReturnsClearCompatibilityEnvelope() async throws {
        let manager = StickyManager(
            store: StickyStore(),
            yabai: FakeYabaiQuerying(currentSpace: WorkspaceID(rawValue: 1)),
            panelSync: InMemoryPanelSync()
        )
        let server = IPCServer(manager: manager)
        let requestLine = try IPCWireCodec.encodeRequestLine(
            .hello(protocolVersion: IPCServer.protocolVersion + 1)
        )
        let responseLine = await server.handleLine(requestLine)
        let response = try IPCWireCodec.decodeResponseLine(responseLine)

        guard case .protocolMismatch(let server, let minClient, let message) = response else {
            Issue.record("expected protocol mismatch response")
            return
        }
        #expect(server == IPCServer.protocolVersion)
        #expect(minClient == IPCServer.minSupportedClientVersion)
        #expect(message.contains("Unsupported client protocol version"))
    }
}
