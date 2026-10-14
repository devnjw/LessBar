import AppKit

/// Handle ordinary presses before NSStatusBarButton starts its highlighted
/// tracking loop. Like recovery, reveal/hide happens on mouse-down only.
@MainActor
enum NativeChevronPress {
    static func consume(_ event: NSEvent, onPress: () -> Void) -> Bool {
        guard event.type == .leftMouseDown, !event.modifierFlags.contains(.command),
              let window = event.window,
              window.level.rawValue == Int(CGWindowLevelForKey(.statusWindow)),
              let content = window.contentView,
              let button = statusButton(in: content), button.isEnabled,
              !button.isHiddenOrHasHiddenAncestor else { return false }
        onPress()
        return true
    }

    private static func statusButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        return view.subviews.lazy.compactMap { statusButton(in: $0) }.first
    }
}
