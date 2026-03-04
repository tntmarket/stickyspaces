import Foundation
import Testing
@testable import StickySpacesShared
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
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()

        let finish = try await session.harness.stopRecording()
        #expect([CaptureBackendKind.screenCaptureKit, .screencapture].contains(finish.backendKind))
        #expect(FileManager.default.fileExists(atPath: session.videoURL.path))

        let size = try session.videoFileSizeBytes()
        #expect(size > 0)
    }

    @Test("zoom-out first frame matches pre-zoom frame")
    func zoomOutFirstFrameMatchesPreZoomFrame() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-frame-a-b-identity")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(
            .createSticky(text: "Frame continuity hero", x: 230, y: 520)
        )
        _ = try await session.harness.step(.wait(milliseconds: 160))

        let frameA = try await session.harness.captureScreenshot(name: "frame-a-pre-zoom")
        _ = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        #expect(captureResult?.source == .liveCapture)
        let frameB = try await session.harness.captureScreenshot(name: "frame-b-after-prepare")

        let diff = try ScreenshotMetrics.diff(
            baselineURL: frameA,
            candidateURL: frameB,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(diff.sampledPixelCount > 0)
        #expect(diff.changedPixelRatio <= 0.001)
        #expect(diff.maxChannelDelta <= 2)
    }

    @Test("zoom-out animation preserves hero-anchor continuity")
    func zoomOutAnimationPreservesHeroAnchorContinuity() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-hero-anchor-continuity")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(
            .createSticky(text: "Hero anchor continuity note", x: 320, y: 410)
        )
        _ = try await session.harness.step(.wait(milliseconds: 120))

        _ = try await session.harness.prepareZoomOutOverlay()
        let metrics = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()

        #expect(metrics.frameCount >= 20)
        #expect(metrics.heroSampleCount >= 20)
        let maxHeroStep = try #require(metrics.maxHeroAnchorStepPoints)
        #expect(maxHeroStep <= 42)
    }

    @Test("zoom-out transition duration stays within 300-500 ms at p95")
    func zoomOutTransitionDurationWithin300To500msP95() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-duration-p95")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(
            .createSticky(text: "Duration probe sticky", x: 200, y: 420)
        )
        _ = try await session.harness.step(.wait(milliseconds: 100))

        let sampleCount = 15
        var durations: [Int] = []
        durations.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
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

    @Test("zoom-out final frame shows scaled workspace screenshots")
    func zoomOutFinalFrameShowsScaledWorkspaceScreenshots() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-final-frame-screenshots")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(
            .createSticky(text: "Workspace 1 screenshot marker", x: 180, y: 640)
        )
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(
            .createSticky(text: "Workspace 2 screenshot marker", x: 300, y: 330)
        )
        _ = try await session.harness.step(.wait(milliseconds: 220))

        let snapshot = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        let firstFrame = try await session.harness.captureScreenshot(name: "final-frame-start")
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let finalFrame = try await session.harness.captureScreenshot(name: "final-frame-end")

        let transitionDiff = try ScreenshotMetrics.diff(
            baselineURL: firstFrame,
            candidateURL: finalFrame,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        let visualStats = try ScreenshotMetrics.visualStats(
            imageURL: finalFrame,
            region: .stableCanvas,
            sampleStride: 3,
            quantizationStep: 32
        )

        #expect(snapshot.regions.count >= 2)
        #expect(snapshot.regions.allSatisfy { $0.thumbnail.displayID != nil })
        #expect(captureResult?.source == .liveCapture)
        #expect(transitionDiff.changedPixelRatio >= 0.08)
        #expect(visualStats.quantizedColorCount >= 32)
        #expect(visualStats.luminanceStdDev >= 12)
    }

    @Test("zoom-out does not switch workspace")
    func zoomOutDoesNotSwitchWorkspace() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-does-not-switch-workspace")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(
            .createSticky(text: "Workspace stability sticky", x: 260, y: 450)
        )
        _ = try await session.harness.step(.wait(milliseconds: 100))

        let before = try await session.harness.currentWorkspaceID()
        _ = try await session.harness.prepareZoomOutOverlay()
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let after = try await session.harness.currentWorkspaceID()

        #expect(before == WorkspaceID(rawValue: 2))
        #expect(after == before)
    }

    @Test("zoom-out presentation mutations are transient")
    func zoomOutPresentationMutationsAreTransient() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-transient-presentation-mutations")
        defer { Task { try? await session.harness.cleanup() } }

        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        _ = try await session.harness.step(
            .createSticky(text: "Transient check w1", x: 180, y: 560)
        )
        _ = try await session.harness.step(.switchWorkspace(2))
        _ = try await session.harness.step(
            .createSticky(text: "Transient check w2", x: 240, y: 360)
        )
        _ = try await session.harness.step(.switchWorkspace(1))
        await session.harness.showOnlyWorkspace(workspace1)

        let beforeNotes = try await session.harness.listStickies(space: nil)
        let beforeLayout = try await session.harness.canvasLayout()
        let beforeWorkspace = try await session.harness.currentWorkspaceID()
        let beforeVisibleWorkspace1 = await session.harness.visibleStickyIDs(on: workspace1)

        _ = try await session.harness.prepareZoomOutOverlay()
        _ = try await session.harness.animatePreparedZoomOutOverlayCollectingMetrics()
        let hiddenWorkspace1 = await session.harness.visibleStickyIDs(on: workspace1)
        let hiddenWorkspace2 = await session.harness.visibleStickyIDs(on: workspace2)

        await session.harness.hideZoomOutOverlay()
        await session.harness.showOnlyWorkspace(workspace1)

        let afterVisibleWorkspace1 = await session.harness.visibleStickyIDs(on: workspace1)
        let afterNotes = try await session.harness.listStickies(space: nil)
        let afterLayout = try await session.harness.canvasLayout()
        let afterWorkspace = try await session.harness.currentWorkspaceID()

        #expect(hiddenWorkspace1.isEmpty)
        #expect(hiddenWorkspace2.isEmpty)
        #expect(afterVisibleWorkspace1 == beforeVisibleWorkspace1)
        #expect(afterNotes == beforeNotes)
        #expect(afterLayout == beforeLayout)
        #expect(afterWorkspace == beforeWorkspace)
    }

    @Test("repeated prepare after animation still captures faithful desktop background")
    func repeatedPrepareAfterAnimationStillCapturesFaithfulDesktopBackground() async throws {
        guard VideoBackedScenarioSession.isEnabled else {
            return
        }
        let session = try await makeSession(scenarioName: "zoom-out-repeated-prepare-fidelity")
        defer { Task { try? await session.harness.cleanup() } }

        _ = try await session.harness.step(.wait(milliseconds: 100))

        _ = try await session.harness.prepareZoomOutOverlay()
        let frameAfterFirstPrepare = try await session.harness.captureScreenshot(
            name: "frame-after-first-prepare"
        )

        try await session.harness.animatePreparedZoomOutOverlay()

        _ = try await session.harness.prepareZoomOutOverlay()
        let captureResult = await session.harness.backgroundCaptureResult()
        #expect(captureResult?.source == .liveCapture)
        let frameAfterSecondPrepare = try await session.harness.captureScreenshot(
            name: "frame-after-second-prepare"
        )

        let diff = try ScreenshotMetrics.diff(
            baselineURL: frameAfterFirstPrepare,
            candidateURL: frameAfterSecondPrepare,
            region: .stableCanvas,
            perChannelTolerance: 2,
            sampleStride: 2
        )
        #expect(diff.sampledPixelCount > 0)
        #expect(diff.changedPixelRatio <= 0.05)
        #expect(diff.maxChannelDelta <= 100)
    }

    private func fileSizeBytes(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = attributes[.size] as? NSNumber ?? 0
        return number.int64Value
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
