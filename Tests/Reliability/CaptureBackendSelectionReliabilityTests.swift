import Foundation
import Testing
@testable import VideoCaptureCore

@Suite("Capture backend selection reliability")
struct CaptureBackendSelectionReliabilityTests {
    @Test("auto mode falls back to screencapture when ScreenCaptureKit start fails")
    func autoModeFallsBackToLegacyBackend() async throws {
        let primary = FakeCaptureBackend(kind: .screenCaptureKit, startError: CaptureError.permissionDenied)
        let fallback = FakeCaptureBackend(kind: .screencapture)
        let logger = InMemoryCaptureLogger()
        let selector = CaptureBackendSelector(
            primary: primary,
            fallback: fallback,
            mode: .auto,
            logger: logger
        )

        let selected = try await selector.selectAndStart(
            request: CaptureStartRequest(
                outputURL: temporaryOutputURL(name: "selector-auto.mov"),
                displayID: 1,
                maxDurationSeconds: 1
            )
        )

        #expect(selected.kind == CaptureBackendKind.screencapture)
        #expect(await primary.startCount == 1)
        #expect(await fallback.startCount == 1)
        #expect(logger.lines.contains(where: { $0.contains("fallback_reason=screen-recording-permission-denied") }))
    }

    @Test("forced ScreenCaptureKit mode fails without fallback")
    func forcedScreenCaptureKitModeFailsWithoutFallback() async throws {}

    @Test("auto mode keeps ScreenCaptureKit when primary start succeeds")
    func autoModeDoesNotFallbackWhenPrimaryStartSucceeds() async throws {}

    @Test("permission denied errors include actionable remediation")
    func reportsPermissionDeniedWithActionableRemediation() async throws {}
}
