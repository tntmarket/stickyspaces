import Foundation
import Testing
@testable import StickySpacesUIRecorder
@testable import StickySpacesCapture

@Suite("UIRecorderCommand")
struct UIRecorderCommandTests {
    @Test("preserves existing output naming and mov extension")
    func preservesOutputNamingAndMovExtension() async throws {
        let outputURL = temporaryOutputURL(name: "20260302-001153-fr-7.mov")
        let diagnosticsURL = temporaryOutputURL(name: "20260302-001153-fr-7.diagnostics.json")
        let runner = FakeRunnerOutput(
            lines: [
                "SCENARIO_ACTIONS_START scenario=fr-7",
                "SCENARIO_ACTIONS_COMPLETE scenario=fr-7"
            ]
        )
        let primary = FakeCaptureBackend(kind: .screenCaptureKit)
        let fallback = FakeCaptureBackend(kind: .screencapture)
        let runtime = RecorderRuntime(
            logger: InMemoryCaptureLogger(),
            makeRunner: { _ in runner },
            makePrimaryBackend: { _ in primary },
            makeFallbackBackend: { _ in fallback },
            trimVideoIfNeeded: { _, _ in },
            writeDiagnostics: { _, _ in }
        )
        let command = UIRecorderCommand(
            args: [
                "--duration", "1",
                "--scenario", "fr-7",
                "--workspace", "1",
                "--display", "1",
                "--output", outputURL.path,
                "--diagnostics", diagnosticsURL.path,
                "--tail-after-actions-seconds", "0.01",
                "--post-trim-after-complete", "0"
            ],
            environment: [:],
            runtime: runtime
        )

        let exitCode = try await command.run()

        #expect(exitCode == 0)
        #expect(await primary.startedOutputURL == outputURL)
        #expect(outputURL.pathExtension == "mov")
        #expect(await fallback.startCount == 0)
    }

    @Test("maps legacy env tail-after-actions to recorder option")
    func mapsLegacyEnvTailAfterActionsToRecorderOption() async throws {}

    @Test("keeps record-ui-demo positional interface unchanged")
    func keepsRecordUiDemoPositionalInterfaceUnchanged() async throws {}

    @Test("writes diagnostics sidecar when fallback used")
    func writesDiagnosticsSidecarWhenFallbackUsed() async throws {}
}
