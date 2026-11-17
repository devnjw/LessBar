import ApplicationServices
import CoreGraphics
import Foundation
import Darwin

/// WindowServer visibility and the window's own fullscreen state remain useful
/// when another application temporarily owns the system presentation options.
enum FullscreenWindowVisibility {
    static func matchesVisibleWindow(fullscreenFrame: CGRect, visibleFrame: CGRect) -> Bool {
        let a = fullscreenFrame, b = visibleFrame
        return a.width > 0 && a.height > 0 &&
            abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 &&
            abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }

    /// Run on the existing AX worker, never on the menu-bar interaction thread.
    static func snapshot(appPIDs: [pid_t]) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let candidates = Set(appPIDs).subtracting([getpid()])
        var framesByPID: [pid_t: [CGRect]] = [:]
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  candidates.contains(pid),
                  window[kCGWindowLayer as String] as? Int == 0,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds),
                  frame.width > 0, frame.height > 0 else { continue }
            framesByPID[pid, default: []].append(frame)
        }
        for (pid, visibleFrames) in framesByPID {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.1)
            guard let appWindows = value(app, kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for window in appWindows {
                AXUIElementSetMessagingTimeout(window, 0.1)
                guard value(window, "AXFullScreen") as? Bool == true,
                      let frame = frame(window) else { continue }
                if visibleFrames.contains(where: {
                    matchesVisibleWindow(fullscreenFrame: frame, visibleFrame: $0)
                }) { return true }
            }
        }
        return false
    }

    private static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute),
              let size = value(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent),
              point.x.isFinite, point.y.isFinite,
              extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return nil }
        return CGRect(origin: point, size: extent)
    }
}
