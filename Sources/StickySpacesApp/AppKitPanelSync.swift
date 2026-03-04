import Foundation
import StickySpacesShared

#if canImport(AppKit)
import AppKit

@MainActor
final class AppKitPanelRegistry {
    private var panelsByStickyID: [UUID: NSPanel] = [:]
    private var workspaceByStickyID: [UUID: WorkspaceID] = [:]

    func show(sticky: StickyNote) {
        let panel: NSPanel
        if let existing = panelsByStickyID[sticky.id] {
            panel = existing
        } else {
            panel = makePanel(sticky: sticky)
            panelsByStickyID[sticky.id] = panel
        }
        workspaceByStickyID[sticky.id] = sticky.workspaceID
        apply(sticky: sticky, to: panel)
        panel.orderFrontRegardless()
    }

    func update(sticky: StickyNote) {
        guard let panel = panelsByStickyID[sticky.id] else {
            return
        }
        workspaceByStickyID[sticky.id] = sticky.workspaceID
        apply(sticky: sticky, to: panel)
    }

    func hide(stickyID: UUID) {
        guard let panel = panelsByStickyID.removeValue(forKey: stickyID) else {
            return
        }
        workspaceByStickyID.removeValue(forKey: stickyID)
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

    func makePanel(sticky: StickyNote) -> NSPanel {
        let rect = NSRect(
            x: sticky.position.x,
            y: sticky.position.y,
            width: sticky.size.width,
            height: sticky.size.height
        )
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Sticky \(sticky.workspaceID.rawValue)"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces]

        let textView = NSTextView(frame: panel.contentView?.bounds ?? .zero)
        textView.isEditable = true
        textView.autoresizingMask = [.width, .height]
        textView.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.75, alpha: 1.0)
        textView.font = NSFont.systemFont(ofSize: 14)
        panel.contentView = textView
        return panel
    }

    private func apply(sticky: StickyNote, to panel: NSPanel) {
        let rect = NSRect(
            x: sticky.position.x,
            y: sticky.position.y,
            width: sticky.size.width,
            height: sticky.size.height
        )
        panel.setFrame(rect, display: true)
        panel.title = "Sticky \(sticky.workspaceID.rawValue)"
        if let textView = panel.contentView as? NSTextView {
            textView.string = sticky.text
            textView.window?.makeFirstResponder(textView)
        }
    }
}

public actor AppKitPanelSync: PanelSyncing {
    private let registry = AppKitPanelRegistry()

    public init() {}

    public func show(stickyID: UUID, workspaceID: WorkspaceID) async {
        let fallback = StickyNote(id: stickyID, text: "", workspaceID: workspaceID)
        await show(sticky: fallback)
    }

    public func show(sticky: StickyNote) async {
        await MainActor.run {
            NSApplication.shared.setActivationPolicy(.accessory)
            registry.show(sticky: sticky)
        }
    }

    public func update(sticky: StickyNote) async {
        await MainActor.run {
            registry.update(sticky: sticky)
        }
    }

    public func hide(stickyID: UUID, workspaceID: WorkspaceID) async {
        await MainActor.run {
            registry.hide(stickyID: stickyID)
        }
    }

    public func hideAll(on workspaceID: WorkspaceID) async {
        await MainActor.run {
            registry.hideAll(on: workspaceID)
        }
    }

    public func visibleStickyIDs(on workspaceID: WorkspaceID) async -> Set<UUID> {
        await MainActor.run {
            registry.visibleStickyIDs(on: workspaceID)
        }
    }
}
#endif
