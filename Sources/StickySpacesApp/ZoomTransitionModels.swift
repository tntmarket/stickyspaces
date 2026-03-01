import Foundation
import StickySpacesShared

public enum ZoomTransitionMode: String, Codable, Sendable, CaseIterable {
    case continuousBridge
    case discreteFallback
}

public struct ZoomTransitionProfile: Codable, Sendable, Equatable {
    public let selectedMode: ZoomTransitionMode
    public let dualModeEnabled: Bool

    public init(selectedMode: ZoomTransitionMode, dualModeEnabled: Bool) {
        self.selectedMode = selectedMode
        self.dualModeEnabled = dualModeEnabled
    }

    public static let phase0Selected = ZoomTransitionProfile(
        selectedMode: .continuousBridge,
        dualModeEnabled: false
    )
}

public struct ZoomTransitionMetrics: Codable, Sendable, Equatable {
    public let mode: ZoomTransitionMode
    public let durationMilliseconds: Int
    public let usedLivenessFallback: Bool

    public init(mode: ZoomTransitionMode, durationMilliseconds: Int, usedLivenessFallback: Bool) {
        self.mode = mode
        self.durationMilliseconds = durationMilliseconds
        self.usedLivenessFallback = usedLivenessFallback
    }
}

public struct ZoomTransitionParityResult: Sendable, Equatable {
    public let passed: Bool
    public let metricsByMode: [ZoomTransitionMode: ZoomTransitionMetrics]

    public init(passed: Bool, metricsByMode: [ZoomTransitionMode: ZoomTransitionMetrics]) {
        self.passed = passed
        self.metricsByMode = metricsByMode
    }
}

enum ZoomTransitionDurationModel {
    static func durationMilliseconds(mode: ZoomTransitionMode, usedLivenessFallback: Bool) -> Int {
        let base: Int
        switch mode {
        case .continuousBridge:
            base = 360
        case .discreteFallback:
            base = 420
        }
        return usedLivenessFallback ? base + 40 : base
    }
}
