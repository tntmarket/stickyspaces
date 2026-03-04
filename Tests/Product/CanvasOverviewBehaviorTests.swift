import CoreGraphics
import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Canvas overview layout and snapshot behavior")
struct CanvasOverviewBehaviorTests {
    @Test("Canvas layout preserves custom workspace positions")
    func canvasLayoutPreservesCustomWorkspacePositions() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let custom = CGPoint(x: 920, y: 140)
        await manager.setWorkspacePosition(workspace2, position: custom)

        let layout = try await manager.canvasLayout()
        #expect(layout.workspacePositions[workspace2] == custom)
        #expect(layout.workspaceDisplayIDs[workspace2] == 1)
    }

    @Test("New workspace gets a non-overlapping default canvas position")
    func newWorkspaceGetsANonOverlappingDefaultCanvasPosition() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let initial = try await manager.canvasLayout()
        #expect(initial.workspacePositions[workspace3] == nil)

        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )

        let afterAdd = try await manager.canvasLayout()
        let newPosition = try #require(afterAdd.workspacePositions[workspace3])
        #expect(newPosition != afterAdd.workspacePositions[workspace1])
        #expect(newPosition != afterAdd.workspacePositions[workspace2])
    }

    @Test("Three workspaces render as non-overlapping overview regions")
    func threeWorkspacesRenderAsNonOverlappingOverviewRegions() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let snapshot = try await manager.zoomOutSnapshot()
        #expect(snapshot.regions.count == 3)

        for i in snapshot.regions.indices {
            for j in snapshot.regions.indices where j > i {
                #expect(snapshot.regions[i].frame.intersects(snapshot.regions[j].frame) == false)
            }
        }
    }

    @Test("Zoom-out snapshot includes empty workspace regions")
    func zoomOutSnapshotIncludesEmptyWorkspaceRegions() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        _ = try await manager.createSticky(text: "Workspace 1 sticky")
        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        _ = try await manager.createSticky(text: "Workspace 2 sticky")

        let snapshot = try await manager.zoomOutSnapshot()
        #expect(snapshot.regions.count == 3)
        let emptyRegion = try #require(snapshot.regions.first(where: { $0.workspaceID == workspace3 }))
        #expect(emptyRegion.stickyCount == 0)
        #expect(emptyRegion.stickyPreviews.isEmpty)
    }

    @Test("Zoom-out returns unsupported mode on capability loss")
    func zoomOutReturnsUnsupportedModeOnCapabilityLoss() async throws {
        let workspace = WorkspaceID(rawValue: 1)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setCapabilities(
            CapabilityState(
                canReadCurrentSpace: true,
                canListSpaces: false,
                canFocusSpace: true,
                canDiffTopology: true
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        do {
            _ = try await manager.zoomOutSnapshot()
            Issue.record("expected zoom-out unsupported mode response when list-spaces is unavailable")
        } catch let error as StickyManagerError {
            switch error {
            case .unsupportedMode(let details):
                #expect(details.command == "zoom-out")
                #expect(details.mode == .degraded)
                #expect(details.reason.contains("list-spaces"))
                #expect(details.warnings.contains { $0.contains("list-spaces") })
            default:
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    @Test("Active workspace highlight follows current workspace")
    func activeWorkspaceHighlightFollowsCurrentWorkspace() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let first = try await manager.zoomOutSnapshot()
        #expect(first.activeWorkspaceID == workspace1)
        #expect(first.regions.first(where: { $0.workspaceID == workspace1 })?.isActive == true)

        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        let second = try await manager.zoomOutSnapshot()
        #expect(second.activeWorkspaceID == workspace2)
        #expect(second.regions.first(where: { $0.workspaceID == workspace2 })?.isActive == true)
        #expect(second.regions.first(where: { $0.workspaceID == workspace1 })?.isActive == false)
    }

    @Test("Active workspace highlight is visible in the canvas")
    func activeWorkspaceHighlightIsVisibleInTheCanvas() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace2)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let snapshot = try await manager.zoomOutSnapshot()
        let activeRegion = try #require(snapshot.regions.first(where: { $0.workspaceID == workspace2 }))
        #expect(activeRegion.isActive)
        #expect(activeRegion.frame.width > 0)
        #expect(activeRegion.frame.height > 0)
        #expect(snapshot.invariants.isEmpty)
    }

    @Test("Panel-to-canvas transform round-trips screen positions")
    func panelToCanvasTransformRoundTripsScreenPositions() async throws {
        let transform = PanelCanvasAlignmentContract(
            canvasOriginInScreenCoords: CGPoint(x: 640, y: 280),
            scale: 0.4
        )
        let sampledPanelPoints = [
            CGPoint(x: 640, y: 280),
            CGPoint(x: 700.25, y: 365.75),
            CGPoint(x: 1220.5, y: 910.125),
            CGPoint(x: 1880.875, y: 1200.25)
        ]

        for panelPoint in sampledPanelPoints {
            let canvasPoint = transform.panelToCanvas(panelPoint)
            let projectedBack = transform.canvasToScreen(canvasPoint)
            let delta = hypot(projectedBack.x - panelPoint.x, projectedBack.y - panelPoint.y)
            #expect(delta < 1.0)
        }
    }

    @Test("Repeated zoom-out snapshots are deterministic")
    func repeatedZoomOutSnapshotsAreDeterministic() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace2)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let baseline = try await manager.zoomOutSnapshot()
        for _ in 0..<10 {
            let next = try await manager.zoomOutSnapshot()
            #expect(next == baseline)
        }
    }

    @Test("Zoom-out snapshot includes full-text sticky previews with normalized geometry")
    func zoomOutSnapshotIncludesFullTextPreviewsWithNormalizedGeometry() async throws {
        let workspace = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let text = """
        Ship overview polish
        - verify timing
        - publish demo
        """
        let created = try await manager.createSticky(text: text)
        try await manager.updateStickyPosition(id: created.sticky.id, x: 120, y: 80)
        try await manager.updateStickySize(id: created.sticky.id, width: 240, height: 120)

        let snapshot = try await manager.zoomOutSnapshot()
        let region = try #require(snapshot.regions.first)
        let preview = try #require(region.stickyPreviews.first)

        #expect(preview.id == created.sticky.id)
        #expect(preview.text == text)
        #expect(preview.header == nil)
        #expect(preview.displayHeader == "Ship overview polish")
        #expect(preview.x == 0.25)
        #expect(preview.y == 0.25)
        #expect(preview.width == 0.5)
        #expect(preview.height == 0.375)
    }

    @Test("Zoom-out snapshot preserves sticky relative geometry within a workspace")
    func zoomOutSnapshotPreservesStickyRelativeGeometryWithinAWorkspace() async throws {
        let workspace = WorkspaceID(rawValue: 4)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let left = try await manager.createSticky(text: "Left")
        try await manager.updateStickyPosition(id: left.sticky.id, x: 80, y: 90)
        let right = try await manager.createSticky(text: "Right")
        try await manager.updateStickyPosition(id: right.sticky.id, x: 260, y: 210)

        let snapshot = try await manager.zoomOutSnapshot()
        let region = try #require(snapshot.regions.first)
        let leftPreview = try #require(region.stickyPreviews.first(where: { $0.id == left.sticky.id }))
        let rightPreview = try #require(region.stickyPreviews.first(where: { $0.id == right.sticky.id }))

        #expect(leftPreview.x < rightPreview.x)
        #expect(leftPreview.y < rightPreview.y)
        #expect(leftPreview.width > 0)
        #expect(rightPreview.width > 0)
    }

    @Test("Overview cards place intent labels above workspace previews")
    func overviewCardsPlaceIntentLabelsAboveWorkspacePreviews() async throws {
        let workspaceRect = CGRect(x: 120, y: 320, width: 480, height: 320)
        let stickyPreviews = [
            CanvasStickyPreview(
                id: UUID(),
                text: "Ship overview polish\n- verify timing\n- publish demo",
                header: nil,
                x: 0.25,
                y: 0.25,
                width: 0.5,
                height: 0.375
            )
        ]

        let layout = WorkspaceOverviewCardLayout.make(
            workspaceRect: workspaceRect,
            stickyPreviews: stickyPreviews,
            scale: CanvasViewportState.defaultOverview.zoomScale
        )

        #expect(layout.workspaceRect == workspaceRect)
        #expect(layout.intentLabelRect.maxY == layout.workspaceRect.minY - WorkspaceOverviewCardLayout.labelGap)
        #expect(layout.cardRect.contains(layout.workspaceRect))
        #expect(layout.cardRect.contains(layout.intentLabelRect))
        #expect(layout.labelText == "Ship overview polish")
    }

    @Test("Intent header falls back to first non-empty line")
    func intentHeaderFallsBackToFirstNonEmptyLine() async throws {
        let withoutHeader = CanvasStickyPreview(
            id: UUID(),
            text: "\n   \nPlan launch sequence\n- verify",
            header: nil,
            x: 0,
            y: 0,
            width: 1,
            height: 1
        )
        #expect(withoutHeader.displayHeader == "Plan launch sequence")

        let explicitHeader = CanvasStickyPreview(
            id: UUID(),
            text: "Body text",
            header: "Pinned Header",
            x: 0,
            y: 0,
            width: 1,
            height: 1
        )
        #expect(explicitHeader.displayHeader == "Pinned Header")
    }

    @Test("Overview mode does not mutate sticky text or position")
    func overviewModeDoesNotMutateStickyTextOrPosition() async throws {
        let workspace = WorkspaceID(rawValue: 9)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 1)],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let created = try await manager.createSticky(text: "Immutable")
        try await manager.updateStickyPosition(id: created.sticky.id, x: 222, y: 333)
        let before = await manager.list(space: workspace)

        _ = try await manager.zoomOutSnapshot()
        _ = try await manager.zoomOutSnapshot()
        let after = await manager.list(space: workspace)

        #expect(before == after)
    }

    @Test("Clicking a sticky in overview focuses its workspace")
    func clickingAStickyInOverviewFocusesItsWorkspace() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    WorkspaceDescriptor(workspaceID: workspace1, index: 1, displayID: 1),
                    WorkspaceDescriptor(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        await yabai.setCurrentBinding(.stable(workspaceID: workspace2, displayID: 1, isPrimaryDisplay: true))
        let created = try await manager.createSticky(text: "Navigate to me")
        await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))

        try await manager.navigateFromCanvasClick(stickyID: created.sticky.id)

        #expect(try await yabai.currentSpaceID() == workspace2)
        #expect(await yabai.focusedSpaces() == [workspace2])
    }

    @Test("Zoom-out snapshot uses synthetic thumbnail metadata by default")
    func zoomOutSnapshotUsesSyntheticThumbnailMetadataByDefault() async throws {
        let workspace = WorkspaceID(rawValue: 6)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [WorkspaceDescriptor(workspaceID: workspace, index: 1, displayID: 7)],
                primaryDisplayID: 7
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        let snapshot = try await manager.zoomOutSnapshot()
        let region = try #require(snapshot.regions.first)
        #expect(region.thumbnail.source == .synthetic)
        #expect(region.thumbnail.displayID == 7)
        #expect(region.thumbnail.capturedAt == nil)
        #expect(region.thumbnail.unavailableReason == nil)
    }

    @Test("Legacy canvas-region payloads default missing thumbnail metadata")
    func legacyCanvasRegionPayloadsDefaultMissingThumbnailMetadata() throws {
        let original = CanvasRegionSnapshot(
            workspaceID: WorkspaceID(rawValue: 9),
            displayID: 3,
            frame: CGRect(x: 10, y: 20, width: 400, height: 280),
            stickyCount: 2,
            isActive: false,
            stickyPreviews: []
        )
        let encoded = try JSONEncoder().encode(original)
        let json = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var legacyPayload = json
        legacyPayload.removeValue(forKey: "thumbnail")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyPayload)

        let decoded = try JSONDecoder().decode(CanvasRegionSnapshot.self, from: legacyData)
        #expect(decoded.thumbnail.source == .synthetic)
        #expect(decoded.thumbnail.displayID == nil)
    }

    @Test("Captured thumbnails become stale after the threshold")
    func capturedThumbnailsBecomeStaleAfterTheThreshold() {
        let now = Date()
        let fresh = CanvasThumbnailMetadata(
            source: .cachedCapture,
            capturedAt: now.addingTimeInterval(-3),
            displayID: 1
        )
        #expect(fresh.isStale(now: now, staleAfter: 5) == false)
        #expect(fresh.isStale(now: now, staleAfter: 2) == true)
    }

    @Test("Synthetic and unavailable thumbnails are never age-stale")
    func syntheticAndUnavailableThumbnailsAreNeverAgeStale() {
        let now = Date()
        let synthetic = CanvasThumbnailMetadata.synthetic
        let unavailable = CanvasThumbnailMetadata(
            source: .unavailable,
            capturedAt: now.addingTimeInterval(-999),
            displayID: 1,
            unavailableReason: "screen-capture-failed"
        )

        #expect(synthetic.isStale(now: now, staleAfter: 0) == false)
        #expect(unavailable.isStale(now: now, staleAfter: 0) == false)
    }
}
