import AppKit
import ApplicationServices

struct DisplayAnchor: Equatable {
    let displayID: CGDirectDisplayID
    let control: CGRect
    let available: CGRect
    var imageFrame: CGRect? = nil
}

struct StatusItemGeometry {
    let windowFrame: CGRect
    var imageFrame: CGRect? = nil

    @MainActor static func capture(_ window: NSWindow) -> Self {
        func findButton(in view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton { return button }
            return view.subviews.lazy.compactMap { findButton(in: $0) }.first
        }
        guard let content = window.contentView, let button = findButton(in: content) else {
            return Self(windowFrame: window.frame)
        }
        let imageFrame = button.image == nil ? nil : button.cell.map {
            window.convertToScreen(button.convert($0.imageRect(forBounds: button.bounds), to: nil))
        }
        return Self(windowFrame: window.frame, imageFrame: imageFrame)
    }
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
    static func recoveryAnchors(items: [StatusItemGeometry], screens: [(UInt32, CGRect, CGRect?)]) -> [DisplayAnchor] {
        screens.compactMap { id, screen, rightArea in
            let candidates = items.filter {
                $0.windowFrame.maxX > screen.minX && $0.windowFrame.maxX <= screen.maxX &&
                abs($0.windowFrame.maxY - screen.maxY) <= 4 && $0.windowFrame.height > 0
            }
            guard let item = candidates.max(by: { $0.windowFrame.maxX < $1.windowFrame.maxX }) else { return nil }
            let window = item.windowFrame
            // Preserve the real native image center, including AppKit's menu-bar
            // padding and baseline. Hidden/oversized boundaries have no artwork.
            let imageFrame = item.imageFrame.flatMap { window.contains($0) ? $0 : nil }
            let centerX = imageFrame?.midX ?? (window.maxX - LayoutSafety.controlWidth / 2)
            let control = CGRect(x: centerX - LayoutSafety.controlWidth / 2,
                y: window.minY, width: LayoutSafety.controlWidth, height: window.height)
            // The notch safe area can be 32pt high while the native menu bar is
            // 33pt high. Preserve the safe horizontal edges and use the actual
            // status window height so the one-point lower edge does not reject it.
            let available = rightArea.map {
                CGRect(x: $0.minX, y: window.minY, width: $0.width, height: window.height)
            } ?? CGRect(x: screen.midX, y: screen.minY,
                width: screen.width / 2, height: screen.height)
            guard available.contains(control) else { return nil }
            return DisplayAnchor(displayID: id, control: control, available: available, imageFrame: imageFrame)
        }
    }

    static func isEmpty(point: CGPoint, menu: CGRect, applicationMenus: [CGRect]?, statusItems: [CGRect]?) -> Bool {
        guard menu.contains(point), let applicationMenus, let statusItems else { return false }
        return !(applicationMenus + statusItems).contains { $0.insetBy(dx: -2, dy: 0).contains(point) }
    }

    /// Capture once for all displays. A partial snapshot cannot prove emptiness.
    @MainActor static func applicationMenuFrames() -> [CGRect]? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              let primary = NSScreen.screens.first else { return nil }
        let reader = AccessibilityGeometryReader()
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let value = reader.attribute(element, kAXMenuBarAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let menu = unsafeDowncast(value, to: AXUIElement.self)
        guard let children = reader.attribute(menu, kAXChildrenAttribute) as? [AXUIElement],
              let frames = AccessibilityGeometryReader.completeFrames(of: children, read: reader.frame) else { return nil }
        return frames.map {
            LayoutSafety.appKitFrame(fromWindowServer: $0, primaryScreenMaxY: primary.frame.maxY)
        }
    }

    @MainActor static func applicationMenuFrames(on screen: NSScreen) -> [CGRect]? {
        applicationMenuFrames(on: screen, measuredFrames: applicationMenuFrames())
    }

    @MainActor static func applicationMenuFrames(on screen: NSScreen, measuredFrames: [CGRect]?) -> [CGRect]? {
        guard let frames = measuredFrames, !frames.isEmpty else { return nil }
        var result = frames.filter { menuBarRect(screen).intersects($0) }
        // AX often reports only the active display. Translate measured widths;
        // exclude the notch conservatively on each destination display.
        if result.isEmpty {
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
}
