import Foundation
import StickySpacesCapture

@main
struct StickySpacesUIRecorderMain {
    static func main() async {
        let command = UIRecorderCommand(
            args: Array(CommandLine.arguments.dropFirst()),
            environment: ProcessInfo.processInfo.environment,
            runtime: .live
        )
        do {
            let exitCode = try await command.run()
            Foundation.exit(exitCode)
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            if case CaptureError.permissionDenied = error {
                FileHandle.standardError.write(
                    Data(
                        """
                        Tip: grant Screen Recording permission to your terminal/IDE
                        in System Settings -> Privacy & Security -> Screen Recording.

                        """.utf8
                    )
                )
            }
            Foundation.exit(1)
        }
    }
}

struct UIRecorderCommand {
    let args: [String]
    let environment: [String: String]
    let runtime: RecorderRuntime

    func run() async throws -> Int32 {
        let options = try RecorderCLIOptions.parse(arguments: args, environment: environment)
        if options.showHelp {
            FileHandle.standardOutput.write(Data(RecorderCLIOptions.helpText.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
            return 0
        }

        let trackingLogger = TrackingCaptureLogger(base: runtime.logger)
        let runner = runtime.makeRunner(runnerCommand(for: options))
        let selector = CaptureBackendSelector(
            primary: runtime.makePrimaryBackend(trackingLogger),
            fallback: runtime.makeFallbackBackend(trackingLogger),
            mode: options.captureBackendMode,
            logger: trackingLogger
        )
        let captureRequest = CaptureStartRequest(
            outputURL: options.outputURL,
            displayID: options.displayID,
            maxDurationSeconds: options.durationSeconds,
            requestPermissionIfNeeded: options.requestPermissionIfNeeded
        )
        let coordinator = RecordingSessionCoordinator(
            scenarioID: options.scenarioID,
            runner: runner,
            captureRequest: captureRequest,
            options: options.sessionOptions,
            startCapture: { request in
                try await selector.selectAndStart(request: request)
            },
            logger: trackingLogger
        )

        let result = try await coordinator.run()

        if options.sessionOptions.postTrimAfterComplete,
           let completeMarkerAt = result.completeMarkerAt
        {
            let elapsed = completeMarkerAt.timeIntervalSince(result.captureStartedAt)
            let targetDuration = max(
                0.5,
                elapsed
                    + options.sessionOptions.tailAfterActionsSeconds
                    + options.sessionOptions.postTrimSafetySeconds
            )
            try runtime.trimVideoIfNeeded(options.outputURL, targetDuration)
        }

        let diagnostics = CaptureDiagnostics(
            scenario: options.scenarioID,
            outputFile: options.outputURL.path,
            backend: result.captureBackendKind.rawValue,
            fallbackReason: trackingLogger.fallbackReason,
            startMarkerSeen: result.startMarkerSeen,
            completeMarkerSeen: result.completeMarkerSeen,
            earlyStopped: result.earlyStopped,
            captureExitCode: result.captureExitCode,
            runnerExitCode: result.runnerExitCode,
            captureStartedAt: result.captureStartedAt,
            captureStoppedAt: result.captureStoppedAt,
            completeMarkerAt: result.completeMarkerAt
        )
        try runtime.writeDiagnostics(diagnostics, options.diagnosticsURL)

        runtime.logger.write("Saved demo video: \(options.outputURL.path)")
        runtime.logger.write("Capture backend: \(result.captureBackendKind.rawValue)")
        return 0
    }

    private func runnerCommand(for options: RecorderCLIOptions) -> RunnerCommand {
        let holdSeconds = max(
            options.postActionsHoldSeconds,
            options.sessionOptions.tailAfterActionsSeconds + 0.2
        )
        let arguments = [
            "swift",
            "run",
            "stickyspaces-ui-e2e",
            "--duration", "\(options.durationSeconds)",
            "--scenario", options.scenarioID,
            "--workspace", "\(options.workspaceID)",
            "--post-actions-hold-seconds", "\(holdSeconds)"
        ]
        return RunnerCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: arguments,
            logFileURL: options.runnerLogURL
        )
    }
}

struct RecorderRuntime: Sendable {
    let logger: CaptureLogWriter
    let makeRunner: @Sendable (RunnerCommand) -> RunnerProcess
    let makePrimaryBackend: @Sendable (CaptureLogWriter) -> CaptureBackend
    let makeFallbackBackend: @Sendable (CaptureLogWriter) -> CaptureBackend
    let trimVideoIfNeeded: @Sendable (URL, Double) throws -> Void
    let writeDiagnostics: @Sendable (CaptureDiagnostics, URL) throws -> Void

    static let live = RecorderRuntime(
        logger: StdoutCaptureLogger(),
        makeRunner: { command in ProcessRunner(command: command) },
        makePrimaryBackend: { logger in ScreenCaptureKitBackend(logger: logger) },
        makeFallbackBackend: { logger in ScreencaptureProcessBackend(logger: logger) },
        trimVideoIfNeeded: trimVideoIfNeeded,
        writeDiagnostics: CaptureDiagnosticsWriter.write
    )

    private static func trimVideoIfNeeded(outputURL: URL, targetDuration: Double) throws {
        let actualDuration = try probeDurationSeconds(videoURL: outputURL)
        guard actualDuration > targetDuration + 0.15 else {
            return
        }

        let trimmedURL = outputURL
            .deletingPathExtension()
            .appendingPathExtension("trim.mov")
        try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel", "error",
                "-i", outputURL.path,
                "-t", String(format: "%.3f", targetDuration),
                "-an",
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "20",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                trimmedURL.path
            ]
        )
        _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: trimmedURL)
    }

    private static func probeDurationSeconds(videoURL: URL) throws -> Double {
        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "ffprobe",
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                videoURL.path
            ]
        )
        guard let duration = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw CaptureError.captureFailed(reason: "ffprobe produced invalid duration output")
        }
        return duration
    }

    @discardableResult
    private static func runProcess(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderrString = String(data: stderrData, encoding: .utf8) ?? "unknown"
            throw CaptureError.captureFailed(reason: "command failed (\(arguments.joined(separator: " "))): \(stderrString)")
        }
        return String(data: stdoutData, encoding: .utf8) ?? ""
    }
}

private struct RecorderCLIOptions {
    let scenarioID: String
    let durationSeconds: Double
    let workspaceID: Int
    let displayID: Int
    let outputURL: URL
    let runnerLogURL: URL?
    let diagnosticsURL: URL
    let captureBackendMode: CaptureBackendMode
    let requestPermissionIfNeeded: Bool
    let postActionsHoldSeconds: Double
    let sessionOptions: RecordingSessionOptions
    let showHelp: Bool

    static let helpText = """
    stickyspaces-ui-recorder options:
      --duration <seconds>
      --scenario <fr-id>
      --workspace <id>
      --display <id>
      --output <path-to-mov>
      --runner-log <path-to-log>
      --diagnostics <path-to-json>
      --post-actions-hold-seconds <seconds>
      --backend <auto|sckit|screencapture>
      -h, --help
    """

    static func parse(arguments: [String], environment: [String: String]) throws -> RecorderCLIOptions {
        let reader = ArgumentReader(arguments)
        let showHelp = reader.hasFlag("-h") || reader.hasFlag("--help")

        let scenarioID = reader.value(for: "--scenario") ?? "fr-1"
        let durationRaw = reader.value(for: "--duration")
            ?? String(CaptureContract.recommendedDurationSeconds(for: scenarioID))
        guard let durationSeconds = Double(durationRaw), durationSeconds > 0 else {
            throw CaptureError.invalidArgument("invalid --duration value: \(durationRaw)")
        }

        let workspaceRaw = reader.value(for: "--workspace") ?? "1"
        guard let workspaceID = Int(workspaceRaw), workspaceID > 0 else {
            throw CaptureError.invalidArgument("invalid --workspace value: \(workspaceRaw)")
        }

        let displayRaw = reader.value(for: "--display") ?? "1"
        guard let displayID = Int(displayRaw), displayID > 0 else {
            throw CaptureError.invalidArgument("invalid --display value: \(displayRaw)")
        }

        let outputURL = URL(fileURLWithPath: reader.value(for: "--output") ?? defaultOutputPath(for: scenarioID))
        if outputURL.pathExtension.lowercased() != CaptureContract.outputFileExtension {
            throw CaptureError.invalidArgument("--output must use .\(CaptureContract.outputFileExtension) extension")
        }

        let runnerLogURL = reader.value(for: "--runner-log").map(URL.init(fileURLWithPath:))
        let diagnosticsURL = URL(fileURLWithPath: reader.value(for: "--diagnostics") ?? defaultDiagnosticsPath(for: outputURL))

        let tailAfterActionsSeconds = parseDouble(
            from: reader.value(for: "--tail-after-actions-seconds") ?? environment[CaptureEnvironmentKey.tailAfterActionsSeconds],
            defaultValue: CaptureContract.defaultTailAfterActionsSeconds
        )
        let stopOnActionsComplete = parseBool(
            from: reader.value(for: "--stop-on-actions-complete") ?? environment[CaptureEnvironmentKey.stopOnActionsComplete],
            defaultValue: CaptureContract.defaultStopOnActionsComplete
        )
        let waitForActionsStart = parseBool(
            from: reader.value(for: "--wait-for-actions-start") ?? environment[CaptureEnvironmentKey.waitForActionsStart],
            defaultValue: CaptureContract.defaultWaitForActionsStart
        )
        let actionStartTimeoutSeconds = parseDouble(
            from: reader.value(for: "--action-start-timeout-seconds") ?? environment[CaptureEnvironmentKey.actionStartTimeoutSeconds],
            defaultValue: CaptureContract.defaultActionStartTimeoutSeconds
        )
        let postTrimAfterComplete = parseBool(
            from: reader.value(for: "--post-trim-after-complete") ?? environment[CaptureEnvironmentKey.postTrimAfterComplete],
            defaultValue: CaptureContract.defaultPostTrimAfterComplete
        )
        let postTrimSafetySeconds = parseDouble(
            from: reader.value(for: "--post-trim-safety-seconds") ?? environment[CaptureEnvironmentKey.postTrimSafetySeconds],
            defaultValue: CaptureContract.defaultPostTrimSafetySeconds
        )
        let postActionsHoldSeconds = parseDouble(
            from: reader.value(for: "--post-actions-hold-seconds"),
            defaultValue: max(0.6, tailAfterActionsSeconds + 0.2)
        )

        let backendMode = CaptureBackendMode(
            rawOrDefault: reader.value(for: "--backend") ?? environment[CaptureEnvironmentKey.captureBackend]
        )
        let requestPermissionIfNeeded = parseBool(
            from: reader.value(for: "--request-permission"),
            defaultValue: true
        )

        return RecorderCLIOptions(
            scenarioID: scenarioID,
            durationSeconds: durationSeconds,
            workspaceID: workspaceID,
            displayID: displayID,
            outputURL: outputURL,
            runnerLogURL: runnerLogURL,
            diagnosticsURL: diagnosticsURL,
            captureBackendMode: backendMode,
            requestPermissionIfNeeded: requestPermissionIfNeeded,
            postActionsHoldSeconds: postActionsHoldSeconds,
            sessionOptions: RecordingSessionOptions(
                waitForActionsStart: waitForActionsStart,
                actionStartTimeoutSeconds: actionStartTimeoutSeconds,
                stopOnActionsComplete: stopOnActionsComplete,
                tailAfterActionsSeconds: tailAfterActionsSeconds,
                postTrimAfterComplete: postTrimAfterComplete,
                postTrimSafetySeconds: postTrimSafetySeconds
            ),
            showHelp: showHelp
        )
    }

    private static func parseBool(from raw: String?, defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        switch raw.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }

    private static func parseDouble(from raw: String?, defaultValue: Double) -> Double {
        guard let raw, let parsed = Double(raw), parsed >= 0 else {
            return defaultValue
        }
        return parsed
    }

    private static func defaultOutputPath(for scenarioID: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        return "artifacts/ui-demos/\(stamp)-\(scenarioID).mov"
    }

    private static func defaultDiagnosticsPath(for outputURL: URL) -> String {
        let outputDirectory = outputURL.deletingLastPathComponent()
        let fileStem = outputURL.deletingPathExtension().lastPathComponent
        return outputDirectory
            .appendingPathComponent("review/diagnostics")
            .appendingPathComponent("\(fileStem).diagnostics.json")
            .path
    }
}

private struct ArgumentReader {
    private let arguments: [String]

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    func value(for option: String) -> String? {
        guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    func hasFlag(_ option: String) -> Bool {
        arguments.contains(option)
    }
}

private final class TrackingCaptureLogger: CaptureLogWriter, @unchecked Sendable {
    private let base: CaptureLogWriter
    private let lock = NSLock()
    private(set) var fallbackReason: String?

    init(base: CaptureLogWriter) {
        self.base = base
    }

    func write(_ line: String) {
        base.write(line)
        if line.contains("[fallback]"), let reasonRange = line.range(of: "fallback_reason=") {
            lock.lock()
            fallbackReason = String(line[reasonRange.upperBound...])
            lock.unlock()
        }
    }
}
