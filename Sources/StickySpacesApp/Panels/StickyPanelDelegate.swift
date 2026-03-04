import Foundation
import CoreGraphics

#if canImport(AppKit)

protocol StickyPanelDelegate: AnyObject, Sendable {
    @MainActor func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint)
    @MainActor func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint)
    @MainActor func stickyPanel(_ stickyID: UUID, didChangeText text: String)
    @MainActor func stickyPanelDidRequestDismiss(_ stickyID: UUID)
}

#endif
