import AppKit

enum MenuBarOccupancy {
    /// On macOS 26, Control Center owns the Window Server records even for
    /// another app's status items. Match native window numbers, never owner PID.
    @MainActor
    static func ownStatusItemFrames() -> [CGRect]? {
        let level = Int(CGWindowLevelForKey(.statusWindow))
        return NSApp.windows.filter { $0.level.rawValue == level }.map(\.frame)
    }

    @MainActor
    static func statusItemFrames() -> [CGRect]? { queryStatusFrames(own: false) }

    @MainActor
    static func hasOpenMenu() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]] else { return true }
        let level = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { window in
            guard let layer = window[kCGWindowLayer as String] as? Int else { return false }
            return layer == level && (window[kCGWindowAlpha as String] as? Double ?? 1) > 0
        }
    }

    @MainActor
    private static func queryStatusFrames(own: Bool) -> [CGRect]? {
        guard let primaryScreen = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                 kCGNullWindowID) as? [[String: Any]] else { return nil }
        let layer = Int(CGWindowLevelForKey(.statusWindow))
        let nativeWindows = NSApp.windows.filter { $0.level.rawValue == layer }
        let ownIDs = Set(nativeWindows.map(\.windowNumber))
        let ownFrames = nativeWindows.map(\.frame)
        return windows.compactMap { window in
            guard let windowLayer = window[kCGWindowLayer as String] as? Int,
                  let number = window[kCGWindowNumber as String] as? Int,
                  windowLayer == layer,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            let frame = LayoutSafety.appKitFrame(fromWindowServer: rect, primaryScreenMaxY: primaryScreen.frame.maxY)
            let ours = ownIDs.contains(number) || ownFrames.contains {
                abs($0.minX - frame.minX) < 0.5 && abs($0.minY - frame.minY) < 0.5 &&
                abs($0.width - frame.width) < 0.5 && abs($0.height - frame.height) < 0.5
            }
            return ours == own ? frame : nil
        }
    }
}
