import Foundation

public struct CaptureBackendSelector: Sendable {
    private let primary: CaptureBackend
    private let fallback: CaptureBackend
    private let mode: CaptureBackendMode
    private let logger: CaptureLogWriter

    public init(
        primary: CaptureBackend,
        fallback: CaptureBackend,
        mode: CaptureBackendMode,
        logger: CaptureLogWriter
    ) {
        self.primary = primary
        self.fallback = fallback
        self.mode = mode
        self.logger = logger
    }

    public func selectAndStart(request: CaptureStartRequest) async throws -> CaptureBackend {
        switch mode {
        case .sckit:
            try await primary.start(request: request)
            return primary
        case .screencapture:
            try await fallback.start(request: request)
            return fallback
        case .auto:
            do {
                try await primary.start(request: request)
                return primary
            } catch {
                logger.write("[fallback] fallback_reason=\(error)")
                try await fallback.start(request: request)
                return fallback
            }
        }
    }
}
