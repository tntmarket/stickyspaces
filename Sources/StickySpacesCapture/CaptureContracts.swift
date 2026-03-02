import Foundation

public enum CaptureBackendKind: String, Sendable, Codable {
    case screenCaptureKit = "sckit"
    case screencapture
}

public enum CaptureBackendMode: String, Sendable, Codable {
    case auto
    case sckit
    case screencapture

    public init(rawOrDefault value: String?) {
        guard let value, let parsed = CaptureBackendMode(rawValue: value) else {
            self = .auto
            return
        }
        self = parsed
    }
}

public enum CaptureContract {
    public static let markerStartPrefix = "SCENARIO_ACTIONS_START scenario="
    public static let markerCompletePrefix = "SCENARIO_ACTIONS_COMPLETE scenario="
    public static let outputFileExtension = "mov"

    public static let defaultTailAfterActionsSeconds = 0.5
    public static let defaultStopOnActionsComplete = true
    public static let defaultWaitForActionsStart = true
    public static let defaultActionStartTimeoutSeconds = 12.0
    public static let defaultPostTrimAfterComplete = true
    public static let defaultPostTrimSafetySeconds = 0.2
    public static let defaultCaptureBackendMode: CaptureBackendMode = .auto

    public static func recommendedDurationSeconds(for scenarioID: String) -> Double {
        switch scenarioID {
        case "fr-7", "fr-9", "fr-10",
             "zoom-out-canvas-overview",
             "arrange-workspace-regions",
             "highlight-active-workspace-in-overview":
            return 8
        case "fr-11", "remove-stickies-for-destroyed-workspace":
            return 9
        default:
            return 7
        }
    }
}

public enum CaptureEnvironmentKey {
    public static let captureBackend = "CAPTURE_BACKEND"
    public static let tailAfterActionsSeconds = "TAIL_AFTER_ACTIONS_SECONDS"
    public static let stopOnActionsComplete = "STOP_ON_ACTIONS_COMPLETE"
    public static let waitForActionsStart = "WAIT_FOR_ACTIONS_START"
    public static let actionStartTimeoutSeconds = "ACTION_START_TIMEOUT_SECONDS"
    public static let postTrimAfterComplete = "POST_TRIM_AFTER_COMPLETE"
    public static let postTrimSafetySeconds = "POST_TRIM_SAFETY_SECONDS"
    public static let keepRunnerLog = "KEEP_RUNNER_LOG"
}

public enum CaptureError: Error, CustomStringConvertible, Sendable {
    case invalidArgument(String)
    case runnerFailed(exitCode: Int32)
    case captureFailed(reason: String)
    case permissionDenied
    case unavailable(reason: String)
    case outputMissing(URL)

    public var description: String {
        switch self {
        case .invalidArgument(let message):
            return "invalid-argument: \(message)"
        case .runnerFailed(let exitCode):
            return "runner-failed: exit=\(exitCode)"
        case .captureFailed(let reason):
            return "capture-failed: \(reason)"
        case .permissionDenied:
            return "screen-recording-permission-denied"
        case .unavailable(let reason):
            return "backend-unavailable: \(reason)"
        case .outputMissing(let url):
            return "capture-produced-no-output: \(url.path)"
        }
    }
}

public struct CaptureStartRequest: Sendable {
    public let outputURL: URL
    public let displayID: Int
    public let maxDurationSeconds: Double
    public let requestPermissionIfNeeded: Bool

    public init(
        outputURL: URL,
        displayID: Int,
        maxDurationSeconds: Double,
        requestPermissionIfNeeded: Bool = true
    ) {
        self.outputURL = outputURL
        self.displayID = displayID
        self.maxDurationSeconds = maxDurationSeconds
        self.requestPermissionIfNeeded = requestPermissionIfNeeded
    }
}

public enum CaptureStopReason: String, Sendable {
    case actionsComplete
    case maxDuration
    case teardown
}

public struct CaptureFinishResult: Sendable {
    public let outputURL: URL
    public let exitCode: Int32
    public let earlyStopped: Bool
    public let backendKind: CaptureBackendKind

    public init(outputURL: URL, exitCode: Int32, earlyStopped: Bool, backendKind: CaptureBackendKind) {
        self.outputURL = outputURL
        self.exitCode = exitCode
        self.earlyStopped = earlyStopped
        self.backendKind = backendKind
    }
}

public struct RecordingSessionOptions: Sendable {
    public let waitForActionsStart: Bool
    public let actionStartTimeoutSeconds: Double
    public let stopOnActionsComplete: Bool
    public let tailAfterActionsSeconds: Double
    public let postTrimAfterComplete: Bool
    public let postTrimSafetySeconds: Double

    public init(
        waitForActionsStart: Bool = CaptureContract.defaultWaitForActionsStart,
        actionStartTimeoutSeconds: Double = CaptureContract.defaultActionStartTimeoutSeconds,
        stopOnActionsComplete: Bool = CaptureContract.defaultStopOnActionsComplete,
        tailAfterActionsSeconds: Double = CaptureContract.defaultTailAfterActionsSeconds,
        postTrimAfterComplete: Bool = CaptureContract.defaultPostTrimAfterComplete,
        postTrimSafetySeconds: Double = CaptureContract.defaultPostTrimSafetySeconds
    ) {
        self.waitForActionsStart = waitForActionsStart
        self.actionStartTimeoutSeconds = actionStartTimeoutSeconds
        self.stopOnActionsComplete = stopOnActionsComplete
        self.tailAfterActionsSeconds = tailAfterActionsSeconds
        self.postTrimAfterComplete = postTrimAfterComplete
        self.postTrimSafetySeconds = postTrimSafetySeconds
    }
}

public struct RecordingSessionResult: Sendable {
    public let startMarkerSeen: Bool
    public let completeMarkerSeen: Bool
    public let earlyStopped: Bool
    public let captureBackendKind: CaptureBackendKind
    public let captureExitCode: Int32
    public let runnerExitCode: Int32
    public let captureStartedAt: Date
    public let captureStoppedAt: Date
    public let completeMarkerAt: Date?
    public let outputURL: URL

    public init(
        startMarkerSeen: Bool,
        completeMarkerSeen: Bool,
        earlyStopped: Bool,
        captureBackendKind: CaptureBackendKind,
        captureExitCode: Int32,
        runnerExitCode: Int32,
        captureStartedAt: Date,
        captureStoppedAt: Date,
        completeMarkerAt: Date?,
        outputURL: URL
    ) {
        self.startMarkerSeen = startMarkerSeen
        self.completeMarkerSeen = completeMarkerSeen
        self.earlyStopped = earlyStopped
        self.captureBackendKind = captureBackendKind
        self.captureExitCode = captureExitCode
        self.runnerExitCode = runnerExitCode
        self.captureStartedAt = captureStartedAt
        self.captureStoppedAt = captureStoppedAt
        self.completeMarkerAt = completeMarkerAt
        self.outputURL = outputURL
    }
}
