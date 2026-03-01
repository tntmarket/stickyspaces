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
}
