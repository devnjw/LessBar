import AppKit

enum MenuBarOccupancy {
    /// Read geometry only. No window images, titles, accessibility access or
    /// screen-recording permission request is needed for this check.
    @MainActor
    static func statusItemFrames() -> [CGRect]? {
        guard let primaryScreen = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        var frames: [CGRect] = []
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let layer = window[kCGWindowLayer as String] as? Int else { return nil }
            guard pid != ownPID, layer == statusLayer else { continue }
            if let alpha = window[kCGWindowAlpha as String] as? Double, alpha == 0 { continue }
            guard let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            frames.append(LayoutSafety.appKitFrame(fromWindowServer: rect,
                                                    primaryScreenMaxY: primaryScreen.frame.maxY))
        }
        return frames
    }
}
