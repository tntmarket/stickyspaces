import Foundation
import Testing
@testable import StickySpacesShared
@testable import VideoCaptureCore

@Suite("Map Overview — zoom out to see the big picture")
struct MapOverviewJourneyTests {
    @Test("zooming out is like zooming out of a country in google maps - the current desktop should pull away, and neighboring workspaces should pan into view")
    func desktopToOverviewJourney() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await VideoBackedScenarioSession.prepare(scenarioName: "zoom-out-overview-journey")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.createSticky(text: "Q2 OKRs", x: 180, y: 640))
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Sprint backlog", x: 280, y: 420))
        _ = try await session.harness.step(.wait(milliseconds: 200))

        let workspaceBefore = try await session.harness.currentWorkspaceID()
        let notesBefore = try await session.harness.listStickies(space: nil)
        let layoutBefore = try await session.harness.canvasLayout()

        try await session.harness.startRecording()
        let frameA = try await session.harness.captureScreenshot(name: "frame-a")

        // The overlay starts zoomed in on the active workspace's screenshot
        let snapshot = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        let frameB = try await session.harness.captureScreenshot(name: "frame-b")

        #expect(snapshot.regions.count >= 2)
        #expect(snapshot.regions.allSatisfy { $0.thumbnail.displayID != nil })
        #expect(captureResult?.source == .liveCapture)

        let abDiff = try ScreenshotMetrics.diff(
            baselineURL: frameA,
            candidateURL: frameB,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(abDiff.changedPixelRatio <= 0.05)

        // The camera zooms out smoothly to show all workspaces as recognizable thumbnails
        let metrics = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let frameC = try await session.harness.captureScreenshot(name: "frame-c")

        #expect(metrics.frameCount >= 20)
        #expect(metrics.heroSampleCount >= 20)
        let maxStep = try #require(metrics.maxHeroAnchorStepPoints)
        #expect(maxStep <= 80)
        #expect(metrics.durationMilliseconds >= 300)
        #expect(metrics.durationMilliseconds <= 800)

        let bcDiff = try ScreenshotMetrics.diff(
            baselineURL: frameB,
            candidateURL: frameC,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(bcDiff.changedPixelRatio >= 0.08)

        let visualStats = try ScreenshotMetrics.visualStats(
            imageURL: frameC,
            region: .stableCanvas,
            sampleStride: 3,
            quantizationStep: 32
        )
        #expect(visualStats.quantizedColorCount >= 24)
        #expect(visualStats.luminanceStdDev >= 6)

        // Closing the overview leaves everything exactly as it was
        _ = try await session.harness.stopRecording()
        await session.harness.hideZoomOutOverlay()

        #expect(try await session.harness.currentWorkspaceID() == workspaceBefore)
        #expect(try await session.harness.listStickies(space: nil) == notesBefore)
        #expect(try await session.harness.canvasLayout() == layoutBefore)

        #expect(FileManager.default.fileExists(atPath: session.videoURL.path))
        #expect(try session.videoFileSizeBytes() > 0)
    }
}
