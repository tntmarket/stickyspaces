import Foundation
import Testing
@testable import VideoCaptureCore

@Suite("Zoom-out canvas overview journey")
struct ZoomOutCanvasOverviewJourneyTests {
    @Test("multi-workspace flow produces zoom-out canvas snapshot and video artifact")
    func multiWorkspaceZoomOutCanvasOverviewProducesSnapshotAndVideoArtifact() async throws {
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

        let beforeOverlayScreenshotURL = try await session.harness.captureScreenshot(name: "before-overlay-shown")
        #expect(FileManager.default.fileExists(atPath: beforeOverlayScreenshotURL.path))
        #expect(try fileSizeBytes(at: beforeOverlayScreenshotURL) > 0)

        let snapshot = try await session.harness.prepareZoomOutOverlay()
        #expect(snapshot.regions.count >= 2)

        let afterOverlayScreenshotURL = try await session.harness.captureScreenshot(name: "after-overlay-shown-before-animation")
        #expect(FileManager.default.fileExists(atPath: afterOverlayScreenshotURL.path))
        #expect(try fileSizeBytes(at: afterOverlayScreenshotURL) > 0)
        try await session.harness.animatePreparedZoomOutOverlay()

        let finish = try await session.harness.stopRecording()
        #expect([CaptureBackendKind.screenCaptureKit, .screencapture].contains(finish.backendKind))
        #expect(FileManager.default.fileExists(atPath: session.videoURL.path))

        let size = try session.videoFileSizeBytes()
        #expect(size > 0)
    }

    private func fileSizeBytes(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = attributes[.size] as? NSNumber ?? 0
        return number.int64Value
    }
}
