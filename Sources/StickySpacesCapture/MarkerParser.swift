import Foundation

public enum MarkerKind: String, Sendable {
    case actionsStart
    case actionsComplete
}

public struct MarkerEvent: Sendable {
    public let kind: MarkerKind
    public let scenarioID: String

    public init(kind: MarkerKind, scenarioID: String) {
        self.kind = kind
        self.scenarioID = scenarioID
    }
}

public struct MarkerParser: Sendable {
    public init() {}

    public func parse(line: String) -> MarkerEvent? {
        if let scenarioID = parseScenarioID(in: line, prefix: CaptureContract.markerStartPrefix) {
            return MarkerEvent(kind: .actionsStart, scenarioID: scenarioID)
        }
        if let scenarioID = parseScenarioID(in: line, prefix: CaptureContract.markerCompletePrefix) {
            return MarkerEvent(kind: .actionsComplete, scenarioID: scenarioID)
        }
        return nil
    }

    private func parseScenarioID(in line: String, prefix: String) -> String? {
        guard let range = line.range(of: prefix) else {
            return nil
        }
        let suffix = line[range.upperBound...]
        let scenario = suffix.split(separator: " ").first.map(String.init) ?? String(suffix)
        guard scenario.isEmpty == false else {
            return nil
        }
        return scenario
    }
}
