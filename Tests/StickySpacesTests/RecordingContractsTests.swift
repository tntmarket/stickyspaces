import Foundation
import Testing
@testable import StickySpacesCapture

@Suite("Recording contracts")
struct RecordingContractsTests {
    @Test("marker tokens and output extension stay backward compatible")
    func markerTokensAndOutputExtensionStayStable() {
        #expect(CaptureContract.markerStartPrefix == "SCENARIO_ACTIONS_START scenario=")
        #expect(CaptureContract.markerCompletePrefix == "SCENARIO_ACTIONS_COMPLETE scenario=")
        #expect(CaptureContract.outputFileExtension == "mov")
    }

    @Test("script environment keys remain stable")
    func scriptEnvironmentKeysRemainStable() {
        #expect(CaptureEnvironmentKey.tailAfterActionsSeconds == "TAIL_AFTER_ACTIONS_SECONDS")
        #expect(CaptureEnvironmentKey.stopOnActionsComplete == "STOP_ON_ACTIONS_COMPLETE")
        #expect(CaptureEnvironmentKey.waitForActionsStart == "WAIT_FOR_ACTIONS_START")
        #expect(CaptureEnvironmentKey.actionStartTimeoutSeconds == "ACTION_START_TIMEOUT_SECONDS")
        #expect(CaptureEnvironmentKey.postTrimAfterComplete == "POST_TRIM_AFTER_COMPLETE")
        #expect(CaptureEnvironmentKey.postTrimSafetySeconds == "POST_TRIM_SAFETY_SECONDS")
    }

    @Test("auto durations mirror shell defaults")
    func autoDurationsMirrorShellDefaults() {
        #expect(CaptureContract.recommendedDurationSeconds(for: "fr-1") == 7)
        #expect(CaptureContract.recommendedDurationSeconds(for: "fr-7") == 8)
        #expect(CaptureContract.recommendedDurationSeconds(for: "fr-9") == 8)
        #expect(CaptureContract.recommendedDurationSeconds(for: "fr-10") == 8)
        #expect(CaptureContract.recommendedDurationSeconds(for: "fr-11") == 9)
        #expect(CaptureContract.recommendedDurationSeconds(for: "zoom-out-canvas-overview") == 8)
        #expect(CaptureContract.recommendedDurationSeconds(for: "remove-stickies-for-destroyed-workspace") == 9)
    }
}
