import AppKit

/// Both controls draw the same fixed-size artwork; only its direction changes.
@MainActor
enum ChevronAppearance {
    static let canvasSize = NSSize(width: 16, height: 16)
    private static let expanded = makeImage(mirrored: false)
    private static let collapsed = makeImage(mirrored: true)

    static func image(collapsed: Bool) -> NSImage? {
        collapsed ? self.collapsed : expanded
    }

    static func configure(_ button: NSButton, collapsed: Bool) {
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.contentTintColor = .white
        button.image = image(collapsed: collapsed)
    }

    private static func makeImage(mirrored: Bool) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular, scale: .medium)
        guard let symbol = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }
        let canvas = NSRect(origin: .zero, size: canvasSize)
        // SF Symbols include baseline padding. Center the alignment rect, then
        // give AppKit a plain image so different button cells cannot restyle it.
        let symbolFrame = NSRect(x: canvas.midX - symbol.alignmentRect.midX,
            y: canvas.midY - symbol.alignmentRect.midY, width: symbol.size.width, height: symbol.size.height)
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            if mirrored {
                let transform = NSAffineTransform()
                transform.translateX(by: canvas.width, yBy: 0)
                transform.scaleX(by: -1, yBy: 1)
                transform.concat()
            }
            symbol.draw(in: symbolFrame)
            NSColor.white.setFill()
            canvas.fill(using: .sourceIn)
            return true
        }
        image.isTemplate = false
        image.alignmentRect = canvas
        return image
    }
}
