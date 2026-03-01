import Foundation
import StickySpacesShared

public enum OperationalPrerequisiteDiagnostics {
    public static func evaluate(
        environment: OperationalEnvironment,
        context: OperationalContext
    ) -> OperationalDiagnosticsSnapshot {
        let accessibility = OperationalDiagnosticItem(
            name: "Accessibility",
            state: environment.accessibilityTrusted ? .ok : .actionRequired,
            message: environment.accessibilityTrusted
                ? "Accessibility permission is granted."
                : "Accessibility permission missing; enable it in System Settings."
        )
        let yabai = OperationalDiagnosticItem(
            name: "yabai",
            state: environment.yabaiReachable ? .ok : .actionRequired,
            message: environment.yabaiReachable
                ? "yabai query endpoint is reachable."
                : "yabai is unavailable; start yabai and verify scripting addition."
        )
        let kmMessage = context == .headless
            ? "Keyboard Maestro trigger missing; wire a local macro to run stickyspaces."
            : "Keyboard Maestro trigger missing."
        let keyboardMaestro = OperationalDiagnosticItem(
            name: "Keyboard Maestro",
            state: environment.keyboardMaestroWired ? .ok : .actionRequired,
            message: environment.keyboardMaestroWired ? "Keyboard Maestro wiring is configured." : kmMessage
        )

        let items = [accessibility, yabai, keyboardMaestro]
        let isDegraded = items.contains { $0.state == .actionRequired }
        return OperationalDiagnosticsSnapshot(status: isDegraded ? .degraded : .ready, items: items)
    }
}
