import Foundation

public enum OperationalContext: String, Codable, Sendable, Equatable {
    case desktop
    case headless
}

public struct OperationalEnvironment: Codable, Sendable, Equatable {
    public let accessibilityTrusted: Bool
    public let yabaiReachable: Bool
    public let keyboardMaestroWired: Bool

    public init(
        accessibilityTrusted: Bool,
        yabaiReachable: Bool,
        keyboardMaestroWired: Bool
    ) {
        self.accessibilityTrusted = accessibilityTrusted
        self.yabaiReachable = yabaiReachable
        self.keyboardMaestroWired = keyboardMaestroWired
    }
}

public enum DiagnosticState: String, Codable, Sendable, Equatable {
    case ok
    case actionRequired
}

public struct OperationalDiagnosticItem: Codable, Sendable, Equatable {
    public let name: String
    public let state: DiagnosticState
    public let message: String

    public init(name: String, state: DiagnosticState, message: String) {
        self.name = name
        self.state = state
        self.message = message
    }
}

public enum OperationalDiagnosticsStatus: String, Codable, Sendable, Equatable {
    case ready
    case degraded
}

public struct OperationalDiagnosticsSnapshot: Codable, Sendable, Equatable {
    public let status: OperationalDiagnosticsStatus
    public let items: [OperationalDiagnosticItem]

    public init(status: OperationalDiagnosticsStatus, items: [OperationalDiagnosticItem]) {
        self.status = status
        self.items = items
    }
}

public enum LocalTransport: String, Codable, Sendable, Equatable {
    case unixDomainSocket
    case inProcess
}

public enum LocalOnlyGuardrail {
    public static let requiresOutboundNetwork = false
    public static let allowedTransports: [LocalTransport] = [.unixDomainSocket, .inProcess]
}

public struct StickyReadabilityContract: Codable, Sendable, Equatable {
    public let minimumFontSizePoints: Double
    public let minimumContrastRatio: Double
    public let hasWindowChrome: Bool

    public init(
        minimumFontSizePoints: Double,
        minimumContrastRatio: Double,
        hasWindowChrome: Bool
    ) {
        self.minimumFontSizePoints = minimumFontSizePoints
        self.minimumContrastRatio = minimumContrastRatio
        self.hasWindowChrome = hasWindowChrome
    }

    public var passesNFR6: Bool {
        minimumFontSizePoints >= 14 && minimumContrastRatio >= 4.5 && hasWindowChrome == false
    }

    public static let defaultContract = StickyReadabilityContract(
        minimumFontSizePoints: 16,
        minimumContrastRatio: 7,
        hasWindowChrome: false
    )
}

public struct NightlyPerformanceReport: Codable, Sendable, Equatable {
    public let nfr1P95Milliseconds: Int
    public let nfr2P95Milliseconds: Int
    public let nfr3MemoryMegabytes: Int

    public init(nfr1P95Milliseconds: Int, nfr2P95Milliseconds: Int, nfr3MemoryMegabytes: Int) {
        self.nfr1P95Milliseconds = nfr1P95Milliseconds
        self.nfr2P95Milliseconds = nfr2P95Milliseconds
        self.nfr3MemoryMegabytes = nfr3MemoryMegabytes
    }
}

public struct NightlyPerformanceSignal: Codable, Sendable, Equatable {
    public let releaseBlocking: Bool
    public let failures: [String]

    public init(releaseBlocking: Bool, failures: [String]) {
        self.releaseBlocking = releaseBlocking
        self.failures = failures
    }
}

public enum NightlyPerformanceGate {
    public static func evaluate(report: NightlyPerformanceReport) -> NightlyPerformanceSignal {
        var failures: [String] = []
        if report.nfr1P95Milliseconds > 100 {
            failures.append("NFR-1 hotkey-to-visible p95 exceeded 100ms")
        }
        if report.nfr2P95Milliseconds < 300 || report.nfr2P95Milliseconds > 500 {
            failures.append("NFR-2 zoom transition p95 outside 300-500ms")
        }
        if report.nfr3MemoryMegabytes > 30 {
            failures.append("NFR-3 memory exceeded 30MB")
        }
        return NightlyPerformanceSignal(releaseBlocking: failures.isEmpty == false, failures: failures)
    }
}
