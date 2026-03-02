import CoreGraphics
import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesShared

@Suite("Canvas layout and snapshot")
struct CanvasLayoutTests {
    @Test("test_canvasLayout_persistsWorkspacePositions")
    func test_canvasLayout_persistsWorkspacePositions() async throws {
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

    @Test("test_canvasLayout_newWorkspaceGetsDefaultPosition")
    func test_canvasLayout_newWorkspaceGetsDefaultPosition() async throws {
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

    @Test("test_canvasLayout_threeWorkspaces_nonOverlapping")
    func test_canvasLayout_threeWorkspaces_nonOverlapping() async throws {
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

    @Test("test_activeWorkspaceHighlight_tracksCurrentWorkspace")
    func test_activeWorkspaceHighlight_tracksCurrentWorkspace() async throws {
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

    @Test("test_activeWorkspaceHighlight_visibleInCanvas")
    func test_activeWorkspaceHighlight_visibleInCanvas() async throws {
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

    @Test("test_panelToCanvasAlignment_matchesScreenPositions")
    func test_panelToCanvasAlignment_matchesScreenPositions() async throws {
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

    @Test("test_zoomOut_isDeterministicAcrossRepeatedInvocations")
    func test_zoomOut_isDeterministicAcrossRepeatedInvocations() async throws {
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

    @Test("test_zoomOutSnapshot_emitsStickyPreviews_withFullTextAndNormalizedGeometry")
    func test_zoomOutSnapshot_emitsStickyPreviews_withFullTextAndNormalizedGeometry() async throws {
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
        Ship FR-7 polish
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
        #expect(preview.displayHeader == "Ship FR-7 polish")
        #expect(preview.x == 0.25)
        #expect(preview.y == 0.25)
        #expect(preview.width == 0.5)
        #expect(preview.height == 0.375)
    }

    @Test("test_zoomOutSnapshot_preservesStickyRelativeGeometryWithinWorkspace")
    func test_zoomOutSnapshot_preservesStickyRelativeGeometryWithinWorkspace() async throws {
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

    @Test("test_overviewLayout_placesMinimalIntentLabelBelowWorkspace")
    func test_overviewLayout_placesMinimalIntentLabelBelowWorkspace() async throws {
        let workspaceRect = CGRect(x: 120, y: 320, width: 480, height: 320)
        let stickyPreviews = [
            CanvasStickyPreview(
                id: UUID(),
                text: "Ship FR-7 polish\n- verify timing\n- publish demo",
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
        #expect(layout.labelText == "Ship FR-7 polish")
    }

    @Test("test_intentPanel_headerFallback_usesFirstLineWhenHeaderMissing")
    func test_intentPanel_headerFallback_usesFirstLineWhenHeaderMissing() async throws {
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

    @Test("test_overviewReadOnly_doesNotMutateStickyTextOrPosition")
    func test_overviewReadOnly_doesNotMutateStickyTextOrPosition() async throws {
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

    @Test("test_navigateFromCanvas_clickSticky_focusesTargetWorkspace")
    func test_navigateFromCanvas_clickSticky_focusesTargetWorkspace() async throws {
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

    @Test("test_zoomOutSnapshot_thumbnailMetadata_defaultsToSyntheticWithDisplay")
    func test_zoomOutSnapshot_thumbnailMetadata_defaultsToSyntheticWithDisplay() async throws {
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

    @Test("test_canvasRegionSnapshot_decodeBackCompat_defaultsMissingThumbnail")
    func test_canvasRegionSnapshot_decodeBackCompat_defaultsMissingThumbnail() throws {
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

    @Test("test_thumbnailMetadata_marksCaptureAsStaleAfterThreshold")
    func test_thumbnailMetadata_marksCaptureAsStaleAfterThreshold() {
        let now = Date()
        let fresh = CanvasThumbnailMetadata(
            source: .cachedCapture,
            capturedAt: now.addingTimeInterval(-3),
            displayID: 1
        )
        #expect(fresh.isStale(now: now, staleAfter: 5) == false)
        #expect(fresh.isStale(now: now, staleAfter: 2) == true)
    }

    @Test("test_thumbnailMetadata_nonCaptureSourcesAreNotAgeStale")
    func test_thumbnailMetadata_nonCaptureSourcesAreNotAgeStale() {
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
