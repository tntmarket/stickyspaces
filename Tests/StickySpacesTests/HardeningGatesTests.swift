import Foundation
import Testing
@testable import StickySpacesApp
@testable import StickySpacesClient
@testable import StickySpacesCLI
@testable import StickySpacesShared

@Suite("Task 7 hardening gates")
struct HardeningGatesTests {
    @Test("operational prerequisite diagnostics are actionable in headless mode")
    func operationalPrerequisiteDiagnosticsActionableHeadless() {
        let diagnostics = OperationalPrerequisiteDiagnostics.evaluate(
            environment: .init(
                accessibilityTrusted: false,
                yabaiReachable: false,
                keyboardMaestroWired: false
            ),
            context: .headless
        )

        #expect(diagnostics.status == .degraded)
        #expect(diagnostics.items.count == 3)
        #expect(diagnostics.items.allSatisfy { $0.state == .actionRequired })
        #expect(diagnostics.items.contains { $0.message.contains("Accessibility") })
        #expect(diagnostics.items.contains { $0.message.contains("yabai") })
        #expect(diagnostics.items.contains { $0.message.contains("Keyboard Maestro") })
    }

    @Test("rapid-switch stress converges and per-space sync passes")
    func rapidSwitchStressConvergesAndPerSpaceSyncPasses() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let workspace3 = WorkspaceID(rawValue: 3)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    .init(workspaceID: workspace1, index: 1, displayID: 1),
                    .init(workspaceID: workspace2, index: 2, displayID: 1),
                    .init(workspaceID: workspace3, index: 3, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )

        for i in 0..<100 {
            let target = [workspace1, workspace2, workspace3][i % 3]
            await yabai.setCurrentBinding(.stable(workspaceID: target, displayID: 1, isPrimaryDisplay: true))
            _ = try await manager.createSticky(text: "stress-\(i)")
        }

        await yabai.setCurrentBinding(.stable(workspaceID: workspace3, displayID: 1, isPrimaryDisplay: true))
        let finalStatus = await manager.status()
        #expect(finalStatus.space == workspace3)

        for space in [workspace1, workspace2, workspace3] {
            let sync = await manager.verifySync(space: space)
            #expect(sync.synced)
        }
    }

    @Test("workspace index renumbering stress preserves workspace identity binding")
    func workspaceIndexRenumberingStressPreservesIDBinding() async throws {
        let workspace = WorkspaceID(rawValue: 200)
        let yabai = FakeYabaiQuerying(currentSpace: workspace)
        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync()
        )
        _ = try await manager.createSticky(text: "bound")

        for i in 1...50 {
            let snapshot = WorkspaceTopologySnapshot(
                spaces: [.init(workspaceID: workspace, index: i, displayID: 1)],
                primaryDisplayID: 1
            )
            _ = await manager.reconcileTopology(snapshot: snapshot, health: .healthy, now: Date(timeIntervalSince1970: TimeInterval(i)))
        }

        let notes = await manager.list(space: workspace)
        #expect(notes.count == 1)
        #expect(notes[0].workspaceID == workspace)
    }

    @Test("topology health-flap fault injection avoids false-positive removal")
    func topologyHealthFlapFaultInjectionAvoidsFalsePositiveRemoval() async {
        let reconciler = WorkspaceTopologyReconciler(confirmationInterval: 2)
        let workspace = WorkspaceID(rawValue: 9)
        let present = WorkspaceTopologySnapshot(
            spaces: [.init(workspaceID: workspace, index: 1, displayID: 1)],
            primaryDisplayID: 1
        )
        let missing = WorkspaceTopologySnapshot(spaces: [], primaryDisplayID: 1)

        _ = await reconciler.reconcile(snapshot: present, health: .healthy, now: Date(timeIntervalSince1970: 0))
        _ = await reconciler.reconcile(snapshot: missing, health: .unhealthy, now: Date(timeIntervalSince1970: 1))
        let unhealthyResult = await reconciler.reconcile(snapshot: missing, health: .unhealthy, now: Date(timeIntervalSince1970: 3))
        #expect(unhealthyResult.confirmedRemoved.isEmpty)

        let healthyMissing1 = await reconciler.reconcile(snapshot: missing, health: .healthy, now: Date(timeIntervalSince1970: 4))
        #expect(healthyMissing1.confirmedRemoved.isEmpty)

        let healthyMissing2 = await reconciler.reconcile(snapshot: missing, health: .healthy, now: Date(timeIntervalSince1970: 7))
        #expect(healthyMissing2.confirmedRemoved == [workspace])
    }

    @Test("IPC protocol skew is rejected with explicit compatibility envelope")
    func ipcProtocolSkewRejected() async throws {
        let app = DemoAppFactory.makeReady()
        let response = try await app.client.handshake(protocolVersion: IPCServer.protocolVersion + 1)

        guard case .protocolMismatch(let server, let minClient, let message) = response else {
            Issue.record("expected protocol mismatch response")
            return
        }
        #expect(server == IPCServer.protocolVersion)
        #expect(minClient == IPCServer.minSupportedClientVersion)
        #expect(message.contains("Unsupported client protocol version"))
    }

    @Test("second-launch lock rejects concurrent launcher")
    func secondLaunchLockRejectsConcurrentLauncher() async {
        let lock = SecondLaunchLock()

        let first = await lock.acquire(ownerID: "launcher-a")
        let second = await lock.acquire(ownerID: "launcher-b")
        await lock.release(ownerID: "launcher-a")
        let third = await lock.acquire(ownerID: "launcher-b")

        #expect(first)
        #expect(second == false)
        #expect(third)
    }

    @Test("yabai focus hang times out, degrades capability, and remains responsive")
    func yabaiHangTimeoutDegradesWithoutDeadlock() async throws {
        let workspace1 = WorkspaceID(rawValue: 1)
        let workspace2 = WorkspaceID(rawValue: 2)
        let yabai = FakeYabaiQuerying(currentSpace: workspace1)
        await yabai.setTopologySnapshot(
            WorkspaceTopologySnapshot(
                spaces: [
                    .init(workspaceID: workspace1, index: 1, displayID: 1),
                    .init(workspaceID: workspace2, index: 2, displayID: 1)
                ],
                primaryDisplayID: 1
            )
        )
        await yabai.setFocusHang(delayMilliseconds: 2_000)

        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: InMemoryPanelSync(),
            timeoutPolicy: .init(focusSpaceTimeoutMilliseconds: 25)
        )

        do {
            try await manager.zoomIn(workspaceID: workspace2)
            Issue.record("expected timeout path")
        } catch let error as StickyManagerError {
            switch error {
            case .unsupportedMode(let details):
                #expect(details.reason.contains("timed out"))
            default:
                Issue.record("unexpected error: \(error)")
            }
        }

        let status = await manager.status()
        #expect(status.mode == .degraded)
        #expect(status.warnings.contains { $0.contains("focus-space") })

        _ = try await manager.createSticky(text: "still responsive")
    }

    @Test("session restart clears in-memory sticky state")
    func sessionRestartClearsState() async throws {
        let firstSession = DemoAppFactory.makeReady()
        _ = try await firstSession.client.new(text: "session scoped")
        let firstList = try await firstSession.client.list(space: nil)
        #expect(firstList.count == 1)

        let secondSession = DemoAppFactory.makeReady()
        let secondList = try await secondSession.client.list(space: nil)
        #expect(secondList.isEmpty)
    }

    @Test("local-only guardrail confirms no outbound network dependency")
    func localOnlyGuardrailNoOutboundNetworkRequired() {
        #expect(LocalOnlyGuardrail.requiresOutboundNetwork == false)
        #expect(LocalOnlyGuardrail.allowedTransports == [.unixDomainSocket, .inProcess])
    }

    @Test("default sticky readability contract meets NFR-6")
    func defaultStickyReadabilityMeetsContract() {
        let contract = StickyReadabilityContract.defaultContract
        #expect(contract.minimumFontSizePoints >= 14)
        #expect(contract.minimumContrastRatio >= 4.5)
        #expect(contract.hasWindowChrome == false)
        #expect(contract.passesNFR6)
    }

    @Test("nightly performance suite emits release-blocking signal on NFR regression")
    func nightlyPerformanceSuiteEmitsReleaseBlockingSignal() {
        let failingReport = NightlyPerformanceReport(
            nfr1P95Milliseconds: 130,
            nfr2P95Milliseconds: 510,
            nfr3MemoryMegabytes: 34
        )

        let signal = NightlyPerformanceGate.evaluate(report: failingReport)
        #expect(signal.releaseBlocking)
        #expect(signal.failures.count == 3)
    }
}
