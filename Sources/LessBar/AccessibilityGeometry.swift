import AppKit
import ApplicationServices

/// AX talks to other processes synchronously. Bound the whole snapshot, not
/// just each message, and never interpret missing geometry as empty space.
struct AccessibilityGeometryReader {
    private let deadline = ProcessInfo.processInfo.systemUptime + 0.1

    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0 else { return nil }
        AXUIElementSetMessagingTimeout(element, Float(min(0.03, remaining)))
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    func frame(_ element: AXUIElement) -> CGRect? {
        Self.frame(position: attribute(element, kAXPositionAttribute),
                   size: attribute(element, kAXSizeAttribute))
    }

    static func frame(position: CFTypeRef?, size: CFTypeRef?) -> CGRect? {
        guard let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent),
              point.x.isFinite, point.y.isFinite, extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return nil }
        return CGRect(origin: point, size: extent)
    }

    static func completeFrames<Item>(of items: [Item], read: (Item) -> CGRect?) -> [CGRect]? {
        guard !items.isEmpty, items.count <= 64 else { return nil }
        var frames: [CGRect] = []
        for item in items {
            guard let frame = read(item) else { return nil }
            frames.append(frame)
        }
        return frames
    }
}
