import Foundation

public struct CaptureDiagnostics: Codable, Sendable {
    public let scenario: String
    public let outputFile: String
    public let backend: String
    public let fallbackReason: String?
    public let startMarkerSeen: Bool
    public let completeMarkerSeen: Bool
    public let earlyStopped: Bool
    public let captureExitCode: Int32
    public let runnerExitCode: Int32
    public let captureStartedAt: Date
    public let captureStoppedAt: Date
    public let completeMarkerAt: Date?

    public init(
        scenario: String,
        outputFile: String,
        backend: String,
        fallbackReason: String?,
        startMarkerSeen: Bool,
        completeMarkerSeen: Bool,
        earlyStopped: Bool,
        captureExitCode: Int32,
        runnerExitCode: Int32,
        captureStartedAt: Date,
        captureStoppedAt: Date,
        completeMarkerAt: Date?
    ) {
        self.scenario = scenario
        self.outputFile = outputFile
        self.backend = backend
        self.fallbackReason = fallbackReason
        self.startMarkerSeen = startMarkerSeen
        self.completeMarkerSeen = completeMarkerSeen
        self.earlyStopped = earlyStopped
        self.captureExitCode = captureExitCode
        self.runnerExitCode = runnerExitCode
        self.captureStartedAt = captureStartedAt
        self.captureStoppedAt = captureStoppedAt
        self.completeMarkerAt = completeMarkerAt
    }
}

public enum CaptureDiagnosticsWriter {
    public static func write(_ diagnostics: CaptureDiagnostics, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(diagnostics)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
