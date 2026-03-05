import Foundation
import Testing
@testable import StickySpacesShared
@testable import VideoCaptureCore

@Suite("Map Overview — zoom out to see the big picture")
struct ZoomOutCanvasOverviewJourneyTests {
    @Test("opening the big picture across workspaces records the full sequence as video")
    func openingBigPictureRecordsFullSequenceAsVideo() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-overview")
        defer { Task { try? await session.harness.cleanup() } }

        try await session.harness.startRecording()
        _ = try await session.harness.step(.createSticky(text: "Meeting prep", x: 210, y: 640))
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Sprint backlog", x: 280, y: 420))
        _ = try await session.harness.step(.wait(milliseconds: 300))

        let snapshot = try await session.harness.prepareZoomOutOverlay()
        #expect(snapshot.regions.count >= 2)
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()

        _ = try await session.harness.stopRecording()
        #expect(FileManager.default.fileExists(atPath: session.videoURL.path))
        #expect(try session.videoFileSizeBytes() > 0)
    }

    @Test("the screen looks identical the instant before zoom motion starts")
    func screenLooksIdenticalBeforeZoomMotionStarts() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-no-flash-before-motion")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.createSticky(text: "Design review", x: 230, y: 520))
        _ = try await session.harness.step(.wait(milliseconds: 160))

        let beforeZoom = try await session.harness.captureScreenshot(name: "before-zoom")
        _ = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        #expect(captureResult?.source == .liveCapture)
        let afterPrepare = try await session.harness.captureScreenshot(name: "after-prepare")

        let diff = try ScreenshotMetrics.diff(
            baselineURL: beforeZoom,
            candidateURL: afterPrepare,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(diff.changedPixelRatio <= 0.001)
        #expect(diff.maxChannelDelta <= 2)
    }

    @Test("the zoom animation moves smoothly without jumping")
    func zoomAnimationMovesSmoothlyWithoutJumping() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-smooth-motion")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.createSticky(text: "Roadmap planning", x: 320, y: 410))
        _ = try await session.harness.step(.wait(milliseconds: 120))

        _ = try await session.harness.prepareZoomOutOverlay()
        let metrics = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()

        #expect(metrics.frameCount >= 20)
        #expect(metrics.heroSampleCount >= 20)
        let maxStep = try #require(metrics.maxHeroAnchorStepPoints)
        #expect(maxStep <= 42)
    }

    @Test("the zoom animation feels responsive (300–500 ms)")
    func zoomAnimationFeelsResponsive() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-responsiveness")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.createSticky(text: "Weekly sync", x: 200, y: 420))
        _ = try await session.harness.step(.wait(milliseconds: 100))

        var durations: [Int] = []
        for _ in 0..<15 {
            _ = try await session.harness.prepareZoomOutOverlay()
            let metrics = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
            durations.append(metrics.durationMilliseconds)
            await session.harness.hideZoomOutOverlay()
            _ = try await session.harness.step(.wait(milliseconds: 50))
        }

        let p95 = p95(of: durations)
        #expect(p95 >= 300)
        #expect(p95 <= 500)
    }

    @Test("the big picture shows recognizable workspace thumbnails, not blank cards")
    func bigPictureShowsRecognizableWorkspaceThumbnails() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-workspace-thumbnails")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.createSticky(text: "Q2 OKRs", x: 180, y: 640))
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Bug triage", x: 300, y: 330))
        _ = try await session.harness.step(.wait(milliseconds: 220))

        let snapshot = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        let beforeAnimation = try await session.harness.captureScreenshot(name: "before-animation")
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let afterAnimation = try await session.harness.captureScreenshot(name: "after-animation")

        let transitionDiff = try ScreenshotMetrics.diff(
            baselineURL: beforeAnimation,
            candidateURL: afterAnimation,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        let visualStats = try ScreenshotMetrics.visualStats(
            imageURL: afterAnimation,
            region: .stableCanvas,
            sampleStride: 3,
            quantizationStep: 32
        )

        #expect(snapshot.regions.allSatisfy { $0.thumbnail.displayID != nil })
        #expect(captureResult?.source == .liveCapture)
        #expect(transitionDiff.changedPixelRatio >= 0.08)
        #expect(visualStats.quantizedColorCount >= 24)
        #expect(visualStats.luminanceStdDev >= 8)
    }

    @Test("opening the big picture keeps you on the same workspace")
    func openingBigPictureKeepsYouOnSameWorkspace() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-stays-on-workspace")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Launch checklist", x: 260, y: 450))
        _ = try await session.harness.step(.wait(milliseconds: 100))

        let before = try await session.harness.currentWorkspaceID()
        _ = try await session.harness.prepareZoomOutOverlay()
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let after = try await session.harness.currentWorkspaceID()

        #expect(before == WorkspaceID(rawValue: 2))
        #expect(after == before)
    }

    @Test("closing the big picture leaves stickies, layout, and workspace unchanged")
    func closingBigPictureLeavesEverythingUnchanged() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-leaves-everything-unchanged")
        defer { Task { try? await session.harness.cleanup() } }

        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        _ = try await session.harness.step(.createSticky(text: "Hiring plan", x: 180, y: 560))
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(.createSticky(text: "Team retro", x: 240, y: 360))
        _ = try await session.harness.step(.switchWorkspace(1))
        await session.harness.showOnlyWorkspace(workspace1)

        let beforeNotes = try await session.harness.listStickies(space: nil)
        let beforeLayout = try await session.harness.canvasLayout()
        let beforeWorkspace = try await session.harness.currentWorkspaceID()
        let beforeVisible = await session.harness.visibleStickyIDs(on: workspace1)

        _ = try await session.harness.prepareZoomOutOverlay()
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let hiddenW1 = await session.harness.visibleStickyIDs(on: workspace1)
        let hiddenW2 = await session.harness.visibleStickyIDs(on: workspace2)

        await session.harness.hideZoomOutOverlay()
        await session.harness.showOnlyWorkspace(workspace1)

        let afterVisible = await session.harness.visibleStickyIDs(on: workspace1)
        let afterNotes = try await session.harness.listStickies(space: nil)
        let afterLayout = try await session.harness.canvasLayout()
        let afterWorkspace = try await session.harness.currentWorkspaceID()

        #expect(hiddenW1.isEmpty)
        #expect(hiddenW2.isEmpty)
        #expect(afterVisible == beforeVisible)
        #expect(afterNotes == beforeNotes)
        #expect(afterLayout == beforeLayout)
        #expect(afterWorkspace == beforeWorkspace)
    }

    @Test("reopening the big picture still shows the real desktop")
    func reopeningBigPictureStillShowsRealDesktop() async throws {
        guard VideoBackedScenarioSession.isEnabled else { return }
        let session = try await makeSession(scenarioName: "zoom-out-reopen-fidelity")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.wait(milliseconds: 100))

        _ = try await session.harness.prepareZoomOutOverlay()
        let firstOpen = try await session.harness.captureScreenshot(name: "first-open")

        try await session.harness.animatePreparedZoomOutOverlay()

        _ = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        #expect(captureResult?.source == .liveCapture)
        let secondOpen = try await session.harness.captureScreenshot(name: "second-open")

        let diff = try ScreenshotMetrics.diff(
            baselineURL: firstOpen,
            candidateURL: secondOpen,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(diff.changedPixelRatio <= 0.05)
        #expect(diff.maxChannelDelta <= 100)
    }

    private func makeSession(scenarioName: String) async throws -> VideoBackedScenarioSession {
        try await VideoBackedScenarioSession.prepare(scenarioName: scenarioName)
    }

    private func p95(of values: [Int]) -> Int {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * 0.95)
        return sorted[index]
    }
}
