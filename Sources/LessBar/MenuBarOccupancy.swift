import AppKit

enum MenuBarOccupancy {
    struct Snapshot {
        let statusFrames: [CGRect]
        let hasOpenMenu: Bool
    }

    /// On macOS 26, Control Center owns the Window Server records even for
    /// another app's status items. Match native window numbers, never owner PID.
    @MainActor
    static func ownStatusItemFrames() -> [CGRect]? {
        let level = Int(CGWindowLevelForKey(.statusWindow))
        return NSApp.windows.filter { $0.level.rawValue == level }.map(\.frame)
    }

    @MainActor
    static func statusItemFrames() -> [CGRect]? { snapshot()?.statusFrames }

    @MainActor
    static func snapshot() -> Snapshot? {
        guard let primaryScreen = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                 kCGNullWindowID) as? [[String: Any]] else { return nil }
        let layer = Int(CGWindowLevelForKey(.statusWindow))
        let nativeWindows = NSApp.windows.filter { $0.level.rawValue == layer }
        let ownIDs = Set(nativeWindows.map(\.windowNumber))
        let ownFrames = nativeWindows.map(\.frame)
        let frames: [CGRect] = windows.compactMap { window in
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
            return ours ? nil : frame
        }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let hasOpenMenu = windows.contains {
            $0[kCGWindowLayer as String] as? Int == menuLevel &&
            ($0[kCGWindowAlpha as String] as? Double ?? 1) > 0
        }
        return Snapshot(statusFrames: frames, hasOpenMenu: hasOpenMenu)
    }
}
