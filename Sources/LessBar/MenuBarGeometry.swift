import AppKit
import ApplicationServices

struct DisplayAnchor: Equatable {
    let displayID: CGDirectDisplayID
    let control: CGRect
    let available: CGRect
}

enum MenuBarGeometry {
    static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func menuBarRect(_ screen: NSScreen) -> CGRect {
        CGRect(x: screen.frame.minX, y: screen.frame.maxY - max(30, NSStatusBar.system.thickness),
               width: screen.frame.width, height: max(30, NSStatusBar.system.thickness))
    }

    static func screen(at point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { menuBarRect($0).contains(point) }
    }

    /// The right edge stays inside the owning display even for an oversized item.
    static func recoveryAnchors(windows: [CGRect], screens: [(UInt32, CGRect, CGRect?)]) -> [DisplayAnchor] {
        screens.compactMap { id, screen, rightArea in
            let candidates = windows.filter {
                $0.maxX > screen.minX && $0.maxX <= screen.maxX &&
                abs($0.maxY - screen.maxY) <= 4 && $0.height > 0
            }
            guard let window = candidates.max(by: { $0.maxX < $1.maxX }) else { return nil }
            let control = CGRect(x: window.maxX - LayoutSafety.controlWidth,
                y: window.minY, width: LayoutSafety.controlWidth, height: window.height)
            // The notch safe area can be 32pt high while the native menu bar is
            // 33pt high. Preserve the safe horizontal edges and use the actual
            // status window height so the one-point lower edge does not reject it.
            let available = rightArea.map {
                CGRect(x: $0.minX, y: window.minY, width: $0.width, height: window.height)
            } ?? CGRect(x: screen.midX, y: screen.minY,
                width: screen.width / 2, height: screen.height)
            guard available.contains(control) else { return nil }
            return DisplayAnchor(displayID: id, control: control, available: available)
        }
    }

    static func isEmpty(point: CGPoint, menu: CGRect, applicationMenus: [CGRect]?, statusItems: [CGRect]?) -> Bool {
        guard menu.contains(point), let applicationMenus, let statusItems else { return false }
        return !(applicationMenus + statusItems).contains { $0.insetBy(dx: -2, dy: 0).contains(point) }
    }

    /// Accessibility exposes application-menu children, not screenshots or content.
    static func applicationMenuFrames(on screen: NSScreen) -> [CGRect]? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              let primary = NSScreen.screens.first else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMenuBarAttribute as CFString, &value) == .success,
              let value else { return nil }
        let menu = unsafeDowncast(value, to: AXUIElement.self)
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }
        var result: [CGRect] = []
        for child in children {
            guard let frame = accessibilityFrame(child, primaryMaxY: primary.frame.maxY) else { continue }
            if menuBarRect(screen).intersects(frame) { result.append(frame) }
        }
        // AX often reports only the active display. Translate measured menu widths
        // to the other display; the empty area remains conservative on notched screens.
        if result.isEmpty {
            let frames = children.compactMap { accessibilityFrame($0, primaryMaxY: primary.frame.maxY) }
            guard let first = frames.first,
                  let source = NSScreen.screens.first(where: { menuBarRect($0).intersects(first) }) else { return nil }
            result = frames.map { $0.offsetBy(dx: screen.frame.minX - source.frame.minX,
                                             dy: screen.frame.maxY - source.frame.maxY) }
        }
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            result.append(CGRect(x: left.maxX, y: screen.frame.maxY - max(30, NSStatusBar.system.thickness),
                width: max(0, right.minX - left.maxX), height: max(30, NSStatusBar.system.thickness)))
        }
        return result.isEmpty ? nil : result
    }

    private static func accessibilityFrame(_ item: AXUIElement, primaryMaxY: CGFloat) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent) else { return nil }
        return LayoutSafety.appKitFrame(fromWindowServer: CGRect(origin: point, size: extent),
                                       primaryScreenMaxY: primaryMaxY)
    }
}
