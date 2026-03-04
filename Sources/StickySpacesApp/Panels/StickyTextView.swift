import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class StickyTextView: NSTextView {
    static let debounceInterval: TimeInterval = 0.5

    let stickyID: UUID
    weak var panelDelegate: StickyPanelDelegate?
    private var pendingWorkItem: DispatchWorkItem?
    private var hasPendingChange = false

    init(stickyID: UUID, delegate: StickyPanelDelegate?) {
        self.stickyID = stickyID
        self.panelDelegate = delegate

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(
            containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        super.init(frame: .zero, textContainer: container)

        isEditable = true
        isRichText = false
        backgroundColor = StickyContentView.backgroundColor
        font = NSFont.systemFont(ofSize: 14)
        textContainerInset = NSSize(width: 4, height: 4)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEndEditing(_:)),
            name: NSText.didEndEditingNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowResignedKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func didChangeText() {
        super.didChangeText()
        scheduleDebounce()
    }

    @objc private func handleEndEditing(_ notification: Notification) {
        flushPendingChange()
    }

    @objc private func handleWindowResignedKey(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        flushPendingChange()
    }

    private func scheduleDebounce() {
        pendingWorkItem?.cancel()
        hasPendingChange = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.commitText()
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.debounceInterval,
            execute: workItem
        )
    }

    func flushPendingChange() {
        guard hasPendingChange else { return }
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        commitText()
    }

    private func commitText() {
        hasPendingChange = false
        pendingWorkItem = nil
        panelDelegate?.stickyPanel(stickyID, didChangeText: string)
    }
}

#endif
