import AppKit
@preconcurrency import ApplicationServices

/// Only the system's Audio/Video privacy control, never Screen Mirroring or
/// an arbitrary status item. Coordinates here use the Window Server origin.
struct SharingIndicator: Equatable {
    let pid: pid_t
    let windowID: CGWindowID
    let frame: CGRect

    static let identifier = "com.apple.menuextra.audiovideo"

    static func matchingWindow(accessibilityFrame: CGRect, windows: [Self]) -> Self? {
        guard accessibilityFrame.width > 0, accessibilityFrame.height > 0 else { return nil }
        let matches = windows.filter {
            $0.frame.contains(accessibilityFrame) &&
            $0.frame.width - accessibilityFrame.width <= 20 &&
            $0.frame.height - accessibilityFrame.height <= 16
        }
        return matches.count == 1 ? matches[0] : nil
    }
}

@MainActor
enum SharingIndicatorLocator {
    static func current() -> SharingIndicator? {
        guard AXIsProcessTrusted(),
              let process = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return nil }
        let app = AXUIElementCreateApplication(process.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let value = attribute(app, kAXExtrasMenuBarAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let bar = unsafeDowncast(value, to: AXUIElement.self)
        guard let children = attribute(bar, kAXChildrenAttribute) as? [AXUIElement],
              let item = children.first(where: {
                  attribute($0, kAXIdentifierAttribute) as? String == SharingIndicator.identifier
              }),
              let position = attribute(item, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(item, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent),
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]] else { return nil }
        let candidates = windows.compactMap { window -> SharingIndicator? in
            guard window[kCGWindowOwnerPID as String] as? Int == Int(process.processIdentifier),
                  window[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.statusWindow)),
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let number = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return SharingIndicator(pid: process.processIdentifier, windowID: number, frame: frame)
        }
        return SharingIndicator.matchingWindow(accessibilityFrame: CGRect(origin: point, size: extent), windows: candidates)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
}

/// Geometry is deliberately independent of the native hiding boundary. Only
/// the privacy indicator is reordered; other items keep their section.
enum SharingIndicatorPlacement {
    static func destination(indicator: CGRect, boundary: CGRect, available: CGRect) -> CGPoint? {
        guard indicator.width > 0, indicator.height > 0,
              boundary.width > 0, boundary.height > 0,
              available.contains(indicator), available.contains(boundary),
              abs(indicator.midY - boundary.midY) < max(indicator.height, boundary.height) / 2,
              indicator.maxX <= boundary.minX + 1 else { return nil }
        let point = CGPoint(x: boundary.maxX + 1, y: indicator.midY)
        return available.contains(point) ? point : nil
    }

    static func isToRight(indicator: CGRect, boundary: CGRect) -> Bool {
        abs(indicator.midY - boundary.midY) < max(indicator.height, boundary.height) / 2 &&
        indicator.minX >= boundary.maxX - 1
    }
}

/// A bounded, asynchronous Command-drag of the identified system control.
/// The caller suspends automatic hide/Command-editing while this runs.
@MainActor
final class SharingIndicatorMover {
    enum Result { case delivered, deferred, failed }
    static let eventTag: Int64 = 0x4c657373426172
    private var releaseEvent: (UUID, CGEvent)?

    func cancel() {
        if let (_, event) = releaseEvent {
            if let pointer = CGEvent(source: nil)?.location { event.location = pointer }
            event.post(tap: .cghidEventTap)
        }
        releaseEvent = nil
    }

    func move(_ indicator: SharingIndicator, to destination: CGPoint) async -> Result {
        guard AXIsProcessTrusted(), NSEvent.pressedMouseButtons == 0,
              NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock).isEmpty,
              SharingIndicatorLocator.current() == indicator,
              let source = CGEventSource(stateID: .hidSystemState) else { return .deferred }
        let start = CGPoint(x: indicator.frame.midX, y: indicator.frame.midY)
        guard let down = event(.leftMouseDown, point: start, source: source),
              let drag = event(.leftMouseDragged, point: destination, source: source),
              let up = event(.leftMouseUp, point: destination, source: source),
              let cancelUp = event(.leftMouseUp, point: start, source: source) else { return .failed }
        guard let pointer = CGEvent(source: nil)?.location else { return .failed }
        var interrupted = false
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .keyDown, .flagsChanged, .scrollWheel]
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated {
                if event.cgEvent?.getIntegerValueField(.eventSourceUserData) != Self.eventTag { interrupted = true }
            }
        }
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated {
                if event.cgEvent?.getIntegerValueField(.eventSourceUserData) != Self.eventTag { interrupted = true }
            }
            return event
        }
        defer {
            if let monitor { NSEvent.removeMonitor(monitor) }
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            if !interrupted, let current = CGEvent(source: nil)?.location,
               [start, destination].contains(where: { hypot(current.x - $0.x, current.y - $0.y) < 3 }) {
                CGWarpMouseCursorPosition(pointer)
            }
        }
        let dragID = UUID()
        releaseEvent = (dragID, cancelUp)
        down.post(tap: .cghidEventTap)
        defer { if releaseEvent?.0 == dragID { cancel() } }
        do {
            try await Task.sleep(for: .milliseconds(80))
            try Task.checkCancellation()
            guard !interrupted else { return .deferred }
            drag.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(80))
            try Task.checkCancellation()
            guard !interrupted else { return .deferred }
            up.post(tap: .cghidEventTap)
            releaseEvent = nil
            try await Task.sleep(for: .milliseconds(150))
            return .delivered
        } catch { return .deferred }
    }

    private func event(_ type: CGEventType, point: CGPoint, source: CGEventSource) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
            mouseCursorPosition: point, mouseButton: .left) else { return nil }
        // The system starts reordering on Command-down. Drag/up must release
        // the modifier so the privacy control commits its new position.
        event.flags = type == .leftMouseDown ? .maskCommand : []
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
        return event
    }
}
