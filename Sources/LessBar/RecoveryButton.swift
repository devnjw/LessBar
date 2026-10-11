import AppKit

/// This control is in a nonactivating panel, not a normal app window. Never
/// consume a click just to activate the window or wait for NSButton tracking.
final class RecoveryButton: NSButton {
    var onReveal: (() -> Void)?
    var onContextMenu: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) { onReveal?() }
    override func mouseUp(with event: NSEvent) { }
    override func rightMouseDown(with event: NSEvent) { onContextMenu?() }
    override func rightMouseUp(with event: NSEvent) { }

    @objc func revealFromAccessibility() { onReveal?() }
}
