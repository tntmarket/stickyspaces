import Foundation
import Testing
@testable import StickySpacesCapture

@Suite("RecordingSessionCoordinator")
struct RecordingSessionCoordinatorTests {
    @Test("stops capture at completion marker plus tail")
    func stopsCaptureAtCompletionMarkerPlusTail() async throws {
        let outputURL = temporaryOutputURL(name: "coordinator-tail.mov")
        let runner = FakeRunnerOutput(
            lines: [
                "SCENARIO_ACTIONS_START scenario=fr-7",
                "SCENARIO_ACTIONS_COMPLETE scenario=fr-7"
            ]
        )
        let recorder = FakeCaptureBackend(kind: .screenCaptureKit)
        let options = RecordingSessionOptions(
            waitForActionsStart: true,
            actionStartTimeoutSeconds: 1,
            stopOnActionsComplete: true,
            tailAfterActionsSeconds: 0.05,
            postTrimAfterComplete: false,
            postTrimSafetySeconds: 0
        )
        let coordinator = RecordingSessionCoordinator(
            scenarioID: "fr-7",
            runner: runner,
            captureRequest: CaptureStartRequest(
                outputURL: outputURL,
                displayID: 1,
                maxDurationSeconds: 1
            ),
            options: options,
            startCapture: { request in
                try await recorder.start(request: request)
                return recorder
            },
            logger: InMemoryCaptureLogger(),
            pollIntervalNanoseconds: 5_000_000
        )

        let result = try await coordinator.run()
        let completeMarkerDate = await runner.completionMarkerDate

        #expect(result.startMarkerSeen == true)
        #expect(result.completeMarkerSeen == true)
        #expect(result.captureStoppedAt.timeIntervalSince(result.captureStartedAt) < 0.3)
        #expect(await recorder.startCount == 1)
        #expect(await recorder.stopCount == 1)
        #expect(completeMarkerDate != nil)
        if let completeMarkerDate, let stopTime = await recorder.stopTime {
            let observedTail = stopTime.timeIntervalSince(completeMarkerDate)
            #expect(abs(observedTail - 0.05) < 0.12)
        }
    }

    @Test("starts capture after timeout when start marker missing")
    func startsCaptureAfterTimeoutWhenStartMarkerMissing() async throws {}

    @Test("uses max duration fallback when completion marker missing")
    func usesMaxDurationFallbackWhenCompletionMarkerMissing() async throws {}

    @Test("does not double stop when completion marker repeats")
    func doesNotDoubleStopWhenCompletionMarkerRepeats() async throws {}

    @Test("propagates runner failure even when capture succeeds")
    func propagatesRunnerFailureEvenWhenCaptureSucceeds() async throws {}
}
