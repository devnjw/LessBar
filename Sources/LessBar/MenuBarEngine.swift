import AppKit

@MainActor
protocol MenuBarEngine: AnyObject {
    var isCollapsed: Bool { get }
    var isSupported: Bool { get }
    var canCollapse: Bool { get }
    func setCollapsed(_ collapsed: Bool)
    func refreshLayout()
}

/// The native item defines the boundary. While expanded in width, its recovery
/// control is hosted separately by RecoveryController so it cannot be clipped with it.
@MainActor
final class LengthMenuBarEngine: MenuBarEngine {
    private let toggle: NSStatusItem
    private(set) var isCollapsed = false
    let isSupported = ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27

    var canCollapse: Bool {
        guard toggle.isVisible, let button = toggle.button,
              let window = button.window, let screen = window.screen else { return false }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return LayoutSafety.isControlVisible(item: frame, screen: screen.frame)
    }

    init(toggle: NSStatusItem) { self.toggle = toggle }

    func setCollapsed(_ collapsed: Bool) {
        isCollapsed = collapsed && isSupported && canCollapse
        refreshLayout()
    }

    func refreshLayout() {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 1440
        toggle.length = isCollapsed ? max(500, min(widest * 2, 10_000)) : LayoutSafety.controlWidth
    }
}
