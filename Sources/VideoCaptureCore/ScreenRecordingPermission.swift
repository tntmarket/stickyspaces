import CoreGraphics
import Foundation

public enum ScreenRecordingPermission: Sendable {
    case granted
    case denied
}

public enum ScreenRecordingPermissionGate {
    public static func ensurePermission(requestIfNeeded: Bool) -> ScreenRecordingPermission {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        guard requestIfNeeded else {
            return .denied
        }
        return CGRequestScreenCaptureAccess() ? .granted : .denied
    }
}
