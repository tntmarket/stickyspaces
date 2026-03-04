import Foundation
import StickySpacesShared

#if canImport(AppKit)
import AppKit

@MainActor
private final class AppKitPanelRegistry: StickyPanelDelegate {
    var panelsByStickyID: [UUID: StickyPanel] = [:]
    var workspaceByStickyID: [UUID: WorkspaceID] = [:]

    var onPositionChanged: ((UUID, CGPoint) -> Void)?
    var onSizeChanged: ((UUID, CGSize, CGPoint) -> Void)?
    var onTextChanged: ((UUID, String) -> Void)?
    var onDismissRequested: ((UUID) -> Void)?

    func show(sticky: StickyNote) {
        let panel: StickyPanel
        if let existing = panelsByStickyID[sticky.id] {
            panel = existing
        } else {
            panel = StickyPanel(stickyID: sticky.id, delegate: self)
            panelsByStickyID[sticky.id] = panel
        }
        workspaceByStickyID[sticky.id] = sticky.workspaceID
        apply(sticky: sticky, to: panel)

        if sticky.focusIntent == .focusTextInputImmediately {
            panel.makeKeyAndOrderFront(nil)
            let textView = panel.stickyContentView.textView
            panel.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        } else {
            panel.orderFrontRegardless()
        }
    }

    func update(sticky: StickyNote) {
        guard let panel = panelsByStickyID[sticky.id] else { return }
        workspaceByStickyID[sticky.id] = sticky.workspaceID
        apply(sticky: sticky, to: panel)
    }

    func hide(stickyID: UUID) {
        guard let panel = panelsByStickyID.removeValue(forKey: stickyID) else { return }
        workspaceByStickyID.removeValue(forKey: stickyID)
        panel.stickyContentView.textView.flushPendingChange()
        panel.orderOut(nil)
        panel.close()
    }

    func hideAll(on workspaceID: WorkspaceID) {
        let ids = workspaceByStickyID
            .filter { $0.value == workspaceID }
            .map(\.key)
        for stickyID in ids {
            hide(stickyID: stickyID)
        }
    }

    func visibleStickyIDs(on workspaceID: WorkspaceID) -> Set<UUID> {
        let ids = workspaceByStickyID
            .filter { $0.value == workspaceID }
            .map(\.key)
        return Set(ids)
    }

    // MARK: - StickyPanelDelegate

    func stickyPanel(_ stickyID: UUID, didMoveToPosition position: CGPoint) {
        onPositionChanged?(stickyID, position)
    }

    func stickyPanel(_ stickyID: UUID, didResizeTo size: CGSize, position: CGPoint) {
        onSizeChanged?(stickyID, size, position)
    }

    func stickyPanel(_ stickyID: UUID, didChangeText text: String) {
        onTextChanged?(stickyID, text)
    }

    func stickyPanelDidRequestDismiss(_ stickyID: UUID) {
        onDismissRequested?(stickyID)
    }

    // MARK: - Private

    private func apply(sticky: StickyNote, to panel: StickyPanel) {
        let rect = NSRect(
            x: sticky.position.x,
            y: sticky.position.y,
            width: sticky.size.width,
            height: sticky.size.height
        )
        panel.setFrame(rect, display: true)
        let textView = panel.stickyContentView.textView
        let isEditing = panel.firstResponder === textView
            || panel.fieldEditor(false, for: textView) === panel.firstResponder
        if !isEditing && textView.string != sticky.text {
            textView.string = sticky.text
        }
    }
}

@MainActor
public final class AppKitPanelSync: PanelSyncing, @unchecked Sendable {
    private var registry: AppKitPanelRegistry?

    private var resolvedRegistry: AppKitPanelRegistry {
        if let registry { return registry }
        let new = AppKitPanelRegistry()
        registry = new
        return new
    }

    nonisolated public init() {}

    public func installManagerCallbacks(_ manager: StickyManager) {
        resolvedRegistry.onPositionChanged = { [weak manager] stickyID, position in
            guard let manager else { return }
            Task { try? await manager.updateStickyPosition(id: stickyID, x: position.x, y: position.y) }
        }
        resolvedRegistry.onSizeChanged = { [weak manager] stickyID, size, position in
            guard let manager else { return }
            Task {
                try? await manager.updateStickyFrame(
                    id: stickyID,
                    x: position.x, y: position.y,
                    width: size.width, height: size.height
                )
            }
        }
        resolvedRegistry.onTextChanged = { [weak manager] stickyID, text in
            guard let manager else { return }
            Task { try? await manager.updateStickyText(id: stickyID, text: text) }
        }
        resolvedRegistry.onDismissRequested = { [weak manager] stickyID in
            guard let manager else { return }
            Task { try? await manager.dismissSticky(id: stickyID) }
        }
    }

    public func show(stickyID: UUID, workspaceID: WorkspaceID) async {
        let fallback = StickyNote(id: stickyID, text: "", workspaceID: workspaceID)
        await show(sticky: fallback)
    }

    public func show(sticky: StickyNote) async {
        NSApplication.shared.setActivationPolicy(.accessory)
        resolvedRegistry.show(sticky: sticky)
    }

    public func update(sticky: StickyNote) async {
        resolvedRegistry.update(sticky: sticky)
    }

    public func hide(stickyID: UUID, workspaceID: WorkspaceID) async {
        resolvedRegistry.hide(stickyID: stickyID)
    }

    public func hideAll(on workspaceID: WorkspaceID) async {
        resolvedRegistry.hideAll(on: workspaceID)
    }

    public func visibleStickyIDs(on workspaceID: WorkspaceID) async -> Set<UUID> {
        resolvedRegistry.visibleStickyIDs(on: workspaceID)
    }
}
#endif
