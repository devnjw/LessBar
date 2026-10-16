import AppKit

/// Follow the actual system menu bar on each display, including temporary
/// reveals in full screen. Presentation options alone cannot describe that.
enum MenuBarVisibility {
    @MainActor static func visibleDisplayIDs() -> Set<CGDirectDisplayID> {
        guard let primary = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]] else { return [] }
        return visibleDisplayIDs(windows: windows, primaryScreenMaxY: primary.frame.maxY,
            screens: NSScreen.screens.map { (MenuBarGeometry.displayID($0), $0.frame) })
    }

    static func visibleDisplayIDs(windows: [[String: Any]], primaryScreenMaxY: CGFloat,
                                  screens: [(CGDirectDisplayID, CGRect)]) -> Set<CGDirectDisplayID> {
        let level = Int(CGWindowLevelForKey(.mainMenuWindow))
        let frames: [CGRect] = windows.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == level,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return LayoutSafety.appKitFrame(fromWindowServer: rect, primaryScreenMaxY: primaryScreenMaxY)
        }
        return Set(screens.compactMap { id, screen in
            // A sliding or hidden menu bar must not leave a floating control.
            // Match the full-width menu bar, never status items or our panels.
            frames.contains {
                $0.height > 0 && $0.height < screen.height &&
                abs($0.maxY - screen.maxY) <= 0.5 &&
                $0.minX <= screen.minX + 0.5 && $0.maxX >= screen.maxX - 0.5
            } ? id : nil
        })
    }
}
