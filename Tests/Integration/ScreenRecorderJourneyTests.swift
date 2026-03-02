import Foundation
import Testing
@testable import VideoCaptureCore

@Suite("Screen recording journeys")
struct ScreenRecorderJourneyTests {
    @Test("user records a multi-workspace flow and zoom-out returns a canvas snapshot")
    func userRecordsMultiWorkspaceFlowAndZoomOutReturnsCanvasSnapshot() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }

        let session = try await VideoBackedScenarioSession.prepare(
            scenarioName: "zoom-out-canvas-overview"
        )
        defer { Task { try? await session.harness.cleanup() } }

        try await session.harness.startRecording()
        _ = try await session.harness.step(.createSticky(text: "Integration: zoom-out entry sticky", x: 210, y: 640))
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Integration: secondary workspace sticky", x: 280, y: 420))
        _ = try await session.harness.step(.wait(milliseconds: 300))
        let zoomOutResult = try await session.harness.step(.zoomOut)
        switch zoomOutResult {
        case .snapshot(let snapshot):
            #expect(snapshot.regions.count >= 2)
        default:
            Issue.record("expected zoomOut step to return snapshot")
        }

        let finish = try await session.harness.stopRecording()
        #expect([CaptureBackendKind.screenCaptureKit, .screencapture].contains(finish.backendKind))
        #expect(FileManager.default.fileExists(atPath: session.videoURL.path))

        let size = try session.videoFileSizeBytes()
        #expect(size > 0)
    }
}
