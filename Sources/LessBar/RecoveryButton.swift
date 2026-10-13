import AppKit

/// This control is in a nonactivating panel, not a normal app window. Never
/// consume a click just to activate the window or wait for NSButton tracking.
final class RecoveryButton: NSButton {
    var onReveal: (() -> Void)?
    var onContextMenu: (() -> Void)?
    /// Native image bounds relative to the recovery panel's bottom-left corner.
    var imageFrame: CGRect?

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        var rect = imageFrame ?? NSRect(x: bounds.midX - image.size.width / 2,
            y: bounds.midY - image.size.height / 2, width: image.size.width, height: image.size.height)
        if isFlipped { rect.origin.y = bounds.maxY - rect.maxY }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) { onReveal?() }
    override func mouseUp(with event: NSEvent) { }
    override func rightMouseDown(with event: NSEvent) { onContextMenu?() }
    override func rightMouseUp(with event: NSEvent) { }

    @objc func revealFromAccessibility() { onReveal?() }
}
