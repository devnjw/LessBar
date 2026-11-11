import AppKit
@preconcurrency import ApplicationServices
import NativeVisibility

/// Only menu-bar visibility is restricted. No assessment-session APIs are used.
/// The Objective-C bridge (MIT, Dwarves Foundation) catches private-API exceptions.
struct NativeMenuBarItem: Sendable {
    let bundle: String
    let frame: CGRect // Accessibility coordinates; x matches AppKit.
}

enum NativeMenuBarSelection {
    static func occupiedFrames(items: [NativeMenuBarItem], allowedBundles: Set<String>?) -> [CGRect] {
        items.filter { allowedBundles?.contains($0.bundle) ?? true }.map(\.frame)
    }

    /// An app with several icons stays visible if any of its icons is visible.
    static func allowed(items: [NativeMenuBarItem], boundary: CGRect, ownBundle: String,
                        leftToRight: Bool) -> [String] {
        let visible = items.filter {
            leftToRight ? $0.frame.midX >= boundary.midX : $0.frame.midX <= boundary.midX
        }.map(\.bundle)
        let systemOwners = items.filter { $0.bundle.hasPrefix("com.apple.") }.map(\.bundle)
        return Set(visible + systemOwners + [ownBundle, "com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"])
            .sorted()
    }
}

@MainActor
final class NativeMenuBarVisibility {
    static var available: Bool { HBNativeVisibilityIsAvailable() }
    private var assertion: AnyObject?
    private var generation = 0
    private(set) var pending = false
    private var hitTestItems: [NativeMenuBarItem] = []
    private var allowedBundles: Set<String>?
    // AX may retain rectangles for restricted icons. Only the current visible
    // identities occupy space; keep filtering at read time across transitions.
    var frames: [CGRect] {
        NativeMenuBarSelection.occupiedFrames(items: hitTestItems, allowedBundles: allowedBundles)
    }
    private var scanning = false
    private var scannedAt: TimeInterval = -Double.infinity

    /// Run cross-process AX calls off the UI thread, with a bounded per-app timeout.
    func snapshot(_ completion: @escaping @MainActor ([NativeMenuBarItem]) -> Void) {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> (pid_t, String)? in
            guard app.bundleURL?.pathExtension == "app", let bundle = app.bundleIdentifier else { return nil }
            return (app.processIdentifier, bundle)
        }
        Task {
            let items = await Task.detached(priority: .userInitiated) {
                Self.readItems(apps)
            }.value
            completion(items)
        }
    }

    nonisolated private static func readItems(_ apps: [(pid_t, String)]) -> [NativeMenuBarItem] {
        var items: [NativeMenuBarItem] = []
        for (pid, bundle) in apps {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.1)
            var bar: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &bar) == .success,
                  let bar else { continue }
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(unsafeDowncast(bar, to: AXUIElement.self),
                kAXChildrenAttribute as CFString, &children) == .success,
                  let children = children as? [AXUIElement] else { continue }
            for child in children {
                var position: CFTypeRef?
                var size: CFTypeRef?
                guard AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &position) == .success,
                      AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &size) == .success,
                      let position, let size,
                      CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { continue }
                var point = CGPoint.zero
                var extent = CGSize.zero
                guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
                      AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent),
                      point.x.isFinite, point.y.isFinite, extent.width > 0, extent.height > 0 else { continue }
                items.append(.init(bundle: bundle, frame: CGRect(origin: point, size: extent)))
            }
        }
        // MenuBarAgent exposes protected system controls in its own window,
        // outside the per-application extras bars used for section selection.
        if let agent = apps.first(where: { $0.1 == "com.apple.MenuBarAgent" }) {
            let root = AXUIElementCreateApplication(agent.0)
            AXUIElementSetMessagingTimeout(root, 0.1)
            func walk(_ element: AXUIElement, depth: Int) {
                guard depth < 4 else { return }
                var role: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
                if depth > 0, role as? String == "AXApplication" { return }
                var identifier: CFTypeRef?
                AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &identifier)
                if let id = identifier as? String, id.hasPrefix("com.apple.menuextra.") {
                    var p: CFTypeRef?; var z: CFTypeRef?
                    if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &p) == .success,
                       AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &z) == .success,
                       let p, let z, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(z) == AXValueGetTypeID() {
                        var point = CGPoint.zero; var size = CGSize.zero
                        if AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point),
                           AXValueGetValue(unsafeDowncast(z, to: AXValue.self), .cgSize, &size), size.width > 0 {
                            items.append(.init(bundle: "com.apple.MenuBarAgent", frame: CGRect(origin: point, size: size)))
                        }
                    }
                    return
                }
                var children: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
                   let children = children as? [AXUIElement] {
                    for child in children { walk(child, depth: depth + 1) }
                }
            }
            walk(root, depth: 0)
        }
        return items
    }

    func refreshFrames() {
        guard AXIsProcessTrusted(), !scanning,
              ProcessInfo.processInfo.systemUptime - scannedAt > 0.5 else { return }
        scanning = true
        snapshot { [weak self] items in
            guard let self else { return }
            scanning = false
            scannedAt = ProcessInfo.processInfo.systemUptime
            guard let primary = NSScreen.screens.first else { return }
            hitTestItems = items.map { .init(bundle: $0.bundle,
                frame: LayoutSafety.appKitFrame(fromWindowServer: $0.frame,
                    primaryScreenMaxY: primary.frame.maxY)) }
        }
    }

    func collapse(boundary: CGRect, completion: @escaping @MainActor (Bool) -> Void) {
        guard Self.available, AXIsProcessTrusted(), !pending else { completion(false); return }
        generation += 1
        let token = generation
        pending = true
        snapshot { [weak self] items in
            guard let self, self.generation == token else { return }
            // Empty inventory must never become an allow-list that hides every app.
            guard !items.isEmpty, AXIsProcessTrusted() else {
                pending = false
                completion(false)
                return
            }
            let allowed = NativeMenuBarSelection.allowed(items: items, boundary: boundary,
                ownBundle: Bundle.main.bundleIdentifier ?? "io.github.devnjw.LessBar",
                leftToRight: NSApp.userInterfaceLayoutDirection == .leftToRight)
            HBNativeVisibilityActivate((0..<64).map { NSNumber(value: $0) }, allowed) { [weak self] result, error in
                MainActor.assumeIsolated {
                    guard let self, self.generation == token else {
                        if let result { HBNativeVisibilityInvalidate(result) }
                        return
                    }
                    self.pending = false
                    guard error == nil, let result else {
                        self.reveal()
                        completion(false)
                        return
                    }
                    let old = self.assertion
                    self.assertion = result as AnyObject
                    self.allowedBundles = Set(allowed)
                    if let old { HBNativeVisibilityInvalidate(old) }
                    completion(true)
                }
            }
        }
        // A missing private-framework callback cannot leave the UI stuck forever.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.generation == token, pending else { return }
            reveal()
            completion(false)
        }
    }

    func reveal() {
        generation += 1
        pending = false
        if let assertion { HBNativeVisibilityInvalidate(assertion) }
        assertion = nil
        allowedBundles = nil
        scannedAt = -Double.infinity
    }
}
