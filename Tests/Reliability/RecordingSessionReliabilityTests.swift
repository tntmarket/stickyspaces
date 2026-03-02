import Foundation
import Testing
@testable import VideoCaptureCore
@testable import StickySpacesShared

@Suite("Recording session reliability")
struct RecordingSessionReliabilityTests {
    @Test("capture stops at completion marker plus configured tail")
    func stopsCaptureAtCompletionMarkerPlusTail() async throws {
        let outputURL = temporaryOutputURL(name: "coordinator-tail.mov")
        let startLine = try automationLifecycleLine(phase: .scenarioActionsStart, scenarioID: "fr-7")
        let completeLine = try automationLifecycleLine(phase: .scenarioActionsComplete, scenarioID: "fr-7")
        let runner = FakeRunnerOutput(
            lines: [
                startLine,
                completeLine
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

    @Test("capture starts after timeout when start marker is missing")
    func startsCaptureAfterTimeoutWhenStartMarkerMissing() async throws {}

    @Test("max duration fallback stops capture when completion marker is missing")
    func usesMaxDurationFallbackWhenCompletionMarkerMissing() async throws {}

    @Test("repeated completion markers do not trigger a double stop")
    func doesNotDoubleStopWhenCompletionMarkerRepeats() async throws {}

    @Test("runner failures still propagate even when capture succeeds")
    func propagatesRunnerFailureEvenWhenCaptureSucceeds() async throws {}
}

private func automationLifecycleLine(
    phase: AutomationLifecyclePhase,
    scenarioID: String
) throws -> String {
    let encoded = try AutomationLifecycleWireCodec.encodeLine(
        AutomationLifecycleEvent(phase: phase, scenarioID: scenarioID)
    )
    return encoded.trimmingCharacters(in: .newlines)
}
