import Foundation
@testable import StickySpacesApp
@testable import StickySpacesCapture
@testable import StickySpacesShared

enum VideoBackedE2EStep: Sendable {
    case switchWorkspace(Int)
    case createSticky(text: String, x: Double, y: Double)
    case wait(milliseconds: Int)
    case zoomOut
}

enum VideoBackedE2EStepResult: Sendable {
    case none
    case sticky(StickyNote)
    case snapshot(CanvasSnapshot)
}

struct VideoBackedScenarioSession: Sendable {
    let scenarioName: String
    let videoURL: URL
    let harness: VideoBackedE2EHarness

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["STICKYSPACES_RUN_SCREEN_RECORDING_TESTS"] == "1"
    }

    static func prepare(
        scenarioName: String,
        filePath: String = #filePath
    ) async throws -> VideoBackedScenarioSession {
        let root = packageRoot(from: filePath)
        let outputRoot = root
            .appendingPathComponent("artifacts/ui-demos/integration-\(UUID().uuidString)")
        let videoURL = outputRoot
            .appendingPathComponent(scenarioName)
            .appendingPathComponent("\(scenarioName).mov")
        let backendMode = CaptureBackendMode(
            rawOrDefault: ProcessInfo.processInfo.environment["CAPTURE_BACKEND"]
        )
        let harness = try await VideoBackedE2EHarness(
            outputURL: videoURL,
            backendMode: backendMode
        )
        return VideoBackedScenarioSession(
            scenarioName: scenarioName,
            videoURL: videoURL,
            harness: harness
        )
    }

    func videoFileSizeBytes() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let number = attributes[.size] as? NSNumber ?? 0
        return number.int64Value
    }

    private static func packageRoot(from filePath: String) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

actor VideoBackedE2EHarness {
    private let outputURL: URL
    private let backendMode: CaptureBackendMode
    private let logger = InMemoryCaptureLogger()
    private let workspace1 = WorkspaceID(rawValue: 1)
    private let workspace2 = WorkspaceID(rawValue: 2)
    private let workspace3 = WorkspaceID(rawValue: 3)

    private let automation: StickySpacesAutomationAPI
    private let debug: StickySpacesAutomationDebugAPI
    private let presenter: AppKitZoomOutOverviewPresenter
    private var activeBackend: CaptureBackend?

    init(outputURL: URL, backendMode: CaptureBackendMode) async throws {
        self.outputURL = outputURL
        self.backendMode = backendMode

        let panelSync = AppKitPanelSync()
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
        await yabai.setCurrentBinding(.stable(workspaceID: workspace1, displayID: 1, isPrimaryDisplay: true))

        let manager = StickyManager(
            store: StickyStore(),
            yabai: yabai,
            panelSync: panelSync
        )
        let presenter = AppKitZoomOutOverviewPresenter()
        self.presenter = presenter
        self.automation = StickySpacesAutomationAPI(
            manager: manager,
            panelSync: panelSync,
            zoomOutPresenter: presenter
        )
        self.debug = StickySpacesAutomationDebugAPI(
            manager: manager,
            panelSync: panelSync,
            yabai: yabai
        )
    }

    func startRecording(maxDurationSeconds: Double = 8, displayID: Int = 1) async throws {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let selector = CaptureBackendSelector(
            primary: ScreenCaptureKitBackend(logger: logger),
            fallback: ScreencaptureProcessBackend(logger: logger),
            mode: backendMode,
            logger: logger
        )
        activeBackend = try await selector.selectAndStart(
            request: CaptureStartRequest(
                outputURL: outputURL,
                displayID: displayID,
                maxDurationSeconds: maxDurationSeconds,
                requestPermissionIfNeeded: true
            )
        )
    }

    func step(_ step: VideoBackedE2EStep) async throws -> VideoBackedE2EStepResult {
        switch step {
        case .switchWorkspace(let workspace):
            let workspaceID = WorkspaceID(rawValue: max(1, workspace))
            await debug.setCurrentBinding(.stable(workspaceID: workspaceID, displayID: 1, isPrimaryDisplay: true))
            return .none
        case .createSticky(let text, let x, let y):
            let createdResponse = try await automation.perform(.createSticky(text: text))
            guard case .created(let created) = createdResponse else {
                throw HarnessError.unexpectedResponse("createSticky")
            }
            _ = try await automation.perform(.moveSticky(id: created.sticky.id, x: x, y: y))
            return .sticky(created.sticky)
        case .wait(let milliseconds):
            try? await Task.sleep(for: .milliseconds(max(0, milliseconds)))
            return .none
        case .zoomOut:
            let response = try await automation.perform(.presentZoomOutOverview)
            guard case .canvasSnapshot(let snapshot) = response else {
                throw HarnessError.unexpectedResponse("presentZoomOutOverview")
            }
            return .snapshot(snapshot)
        }
    }

    func stopRecording() async throws -> CaptureFinishResult {
        guard let activeBackend else {
            throw CaptureError.captureFailed(reason: "recorder was not started")
        }
        try await activeBackend.stop(reason: .teardown)
        let result = try await activeBackend.waitUntilFinished()
        self.activeBackend = nil
        return result
    }

    func cleanup() async throws {
        if let activeBackend {
            try? await activeBackend.stop(reason: .teardown)
            _ = try? await activeBackend.waitUntilFinished()
            self.activeBackend = nil
        }
        await debug.hideAllVisiblePanels()
        await presenter.hide()
    }
}

private enum HarnessError: Error {
    case unexpectedResponse(String)
}
