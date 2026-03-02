import Foundation

public enum AutomationLifecyclePhase: String, Codable, Sendable, Equatable {
    case scenarioActionsStart
    case scenarioActionsComplete
}

public struct AutomationLifecycleEvent: Codable, Sendable, Equatable {
    public let phase: AutomationLifecyclePhase
    public let scenarioID: String

    public init(phase: AutomationLifecyclePhase, scenarioID: String) {
        self.phase = phase
        self.scenarioID = scenarioID
    }
}

public enum AutomationLifecycleWireCodec {
    public static let linePrefix = "STICKYSPACES_AUTOMATION_EVENT "

    public static func encodeLine(_ event: AutomationLifecycleEvent) throws -> String {
        let payload = try JSONEncoder().encode(event)
        guard let encoded = String(data: payload, encoding: .utf8) else {
            throw AutomationLifecycleWireError.invalidUTF8
        }
        return linePrefix + encoded + "\n"
    }

    public static func decodeLine(_ line: String) throws -> AutomationLifecycleEvent {
        let trimmed = line.trimmingCharacters(in: .newlines)
        guard trimmed.hasPrefix(linePrefix) else {
            throw AutomationLifecycleWireError.invalidPrefix
        }
        let payloadStart = trimmed.index(trimmed.startIndex, offsetBy: linePrefix.count)
        let payload = String(trimmed[payloadStart...])
        guard let data = payload.data(using: .utf8) else {
            throw AutomationLifecycleWireError.invalidUTF8
        }
        return try JSONDecoder().decode(AutomationLifecycleEvent.self, from: data)
    }

    public static func parseLine(_ line: String) -> AutomationLifecycleEvent? {
        try? decodeLine(line)
    }
}

public enum AutomationLifecycleWireError: Error {
    case invalidPrefix
    case invalidUTF8
}
