import Foundation

enum LayoutSafety {
    static let controlWidth: CGFloat = 24

    /// Window Server uses a top-left origin; AppKit uses a bottom-left origin.
    static func appKitFrame(fromWindowServer frame: CGRect, primaryScreenMaxY: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryScreenMaxY - frame.maxY,
               width: frame.width, height: frame.height)
    }

    /// Keep the original boundary when free. If a protected system item reflows
    /// into it, place the recovery control just to its left, never over another
    /// item or across the notch. Always start from the anchor to prevent drift.
    static func recoveryFrame(anchor: CGRect, available: CGRect,
                              occupied: [CGRect], maximumShift: CGFloat = 192) -> CGRect? {
        guard anchor.width > 0, anchor.height > 0, available.contains(anchor) else { return nil }
        let obstacles = occupied.filter { $0.width > 0 && $0.height > 0 }
            .map { $0.insetBy(dx: -2, dy: 0) }
        var candidate = anchor
        for _ in 0...obstacles.count {
            let collisions = obstacles.filter { candidate.intersects($0) }
            guard let leftEdge = collisions.map(\.minX).min() else { return candidate }
            candidate.origin.x = leftEdge - candidate.width
            guard available.contains(candidate), anchor.minX - candidate.minX <= maximumShift else {
                return nil
            }
        }
        return nil
    }

    static func controlRect(in item: CGRect) -> CGRect {
        CGRect(x: item.maxX - controlWidth, y: item.minY, width: controlWidth, height: item.height)
    }

    static func isControlVisible(item: CGRect?, screen: CGRect?) -> Bool {
        guard let item, let screen, item.width >= controlWidth, item.height > 0 else { return false }
        return screen.contains(controlRect(in: item))
    }
}
