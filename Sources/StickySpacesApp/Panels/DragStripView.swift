import Foundation

#if canImport(AppKit)
import AppKit

@MainActor
final class DragStripView: NSView {
    static let height: CGFloat = 16
    static let backgroundColor = NSColor(
        calibratedRed: 0.95, green: 0.931, blue: 0.7125, alpha: 1.0
    )

    let stickyID: UUID
    weak var delegate: StickyPanelDelegate?
    let dismissButton = DismissButton(frame: .zero)

    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero
    private var didDrag = false

    init(stickyID: UUID, delegate: StickyPanelDelegate?) {
        self.stickyID = stickyID
        self.delegate = delegate
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Self.backgroundColor.cgColor

        dismissButton.target = self
        dismissButton.action = #selector(dismissClicked)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            dismissButton.widthAnchor.constraint(equalToConstant: DismissButton.size),
            dismissButton.heightAnchor.constraint(equalToConstant: DismissButton.size),
            dismissButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func dismissClicked() {
        delegate?.stickyPanelDidRequestDismiss(stickyID)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        didDrag = true
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y
        let newOrigin = NSPoint(
            x: initialWindowOrigin.x + dx,
            y: initialWindowOrigin.y + dy
        )
        window?.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        guard didDrag, let origin = window?.frame.origin else { return }
        delegate?.stickyPanel(stickyID, didMoveToPosition: origin)
    }
}

#endif
