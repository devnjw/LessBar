import AppKit
@preconcurrency import ApplicationServices
import OSLog

/// AX identities and frames for app selection and original system-item placement.
struct NativeMenuBarItem: Sendable {
    let bundle: String
    let frame: CGRect // Accessibility coordinates; x matches AppKit.
    var identifier: String? = nil
}

enum NativeMenuBarSelection {
    static let recordingIdentifier = "com.apple.menuextra.audiovideo"
    // Only these original system controls are suppressed by this mode. Never
    // discard every MenuBarAgent frame: Clock and Control Center must still work.
    static let restrictedSystemIdentifiers: Set<String> = [recordingIdentifier,
        "com.apple.menuextra.focus", "com.apple.menuextra.focusmode",
        "com.apple.menuextra.airdrop", "com.apple.menuextra.nowplaying",
        "com.apple.menuextra.user", "com.apple.menuextra.fastuserswitcher",
        "com.apple.menuextra.liveactivity", "com.apple.menuextra.liveactivities"]

    static func occupiedFrames(items: [NativeMenuBarItem], allowedBundles: Set<String>?,
                               restrictedFrames: [CGRect] = [], restrictSystemItems: Bool = false) -> [CGRect] {
        let visibleSystemFrames = items.filter {
            $0.identifier != nil && !restrictedSystemIdentifiers.contains($0.identifier!)
        }.map(\.frame)
        func matches(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.midX - b.midX) < 1 && a.maxY > b.minY && a.minY < b.maxY
        }
        return items.filter { item in
            guard allowedBundles?.contains(item.bundle) ?? true else { return false }
            guard restrictSystemItems else { return true }
            if let id = item.identifier { return !restrictedSystemIdentifiers.contains(id) }
            // AXExtrasMenuBar duplicates the agent's named system elements.
            if item.bundle == "com.apple.MenuBarAgent",
               !visibleSystemFrames.contains(where: { matches(item.frame, $0) }),
               restrictedFrames.contains(where: { matches(item.frame, $0) }) { return false }
            return true
        }.map(\.frame)
    }

    private static func section(items: [NativeMenuBarItem], boundary: CGRect, ownBundle: String,
                                screens: [CGRect]) -> (CGRect, [NativeMenuBarItem])? {
        let screen = screens.first { $0.contains(CGPoint(x: boundary.midX, y: boundary.midY)) }
        let dividers = items.filter { $0.bundle == ownBundle &&
            (screen?.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) ?? true) }
        guard let divider = dividers.min(by: {
            hypot($0.frame.midX - boundary.midX, $0.frame.midY - boundary.midY) <
            hypot($1.frame.midX - boundary.midX, $1.frame.midY - boundary.midY)
        })?.frame else { return nil }
        let measuredScreen = screens.first { $0.contains(CGPoint(x: divider.midX, y: divider.midY)) }
        let candidates = items.filter {
            $0.frame.maxY > divider.minY && $0.frame.minY < divider.maxY &&
            (measuredScreen?.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) ?? true)
        }
        return (divider, candidates)
    }

    /// nil means inactive or unobserved, never permission to hide a right-side item.
    static func recordingIsOnHiddenSide(items: [NativeMenuBarItem], boundary: CGRect,
                                       ownBundle: String, screens: [CGRect], leftToRight: Bool) -> Bool? {
        guard let (divider, candidates) = section(items: items, boundary: boundary,
                ownBundle: ownBundle, screens: screens) else { return nil }
        let indicators = candidates.filter { $0.identifier == recordingIdentifier }
        guard !indicators.isEmpty else { return nil }
        return indicators.allSatisfy {
            leftToRight ? $0.frame.midX < divider.midX : $0.frame.midX > divider.midX
        }
    }

    static func isProtectedSystemOwner(_ bundle: String) -> Bool {
        bundle.hasPrefix("com.apple.") && bundle != "com.apple.TextInputMenuAgent"
    }

    /// Compare items and the boundary from the same AX snapshot and menu bar.
    /// An app with several icons stays visible if any of its icons is visible.
    static func allowed(items: [NativeMenuBarItem], boundary: CGRect, ownBundle: String,
                        leftToRight: Bool, screens: [CGRect] = [],
                        systemOwners: [String] = []) -> [String] {
        let (divider, candidates) = section(items: items, boundary: boundary,
            ownBundle: ownBundle, screens: screens) ?? (boundary, items)
        let visible = candidates.filter {
            leftToRight ? $0.frame.midX >= divider.midX : $0.frame.midX <= divider.midX
        }.map(\.bundle)
        let protected = (items.map(\.bundle) + systemOwners).filter(isProtectedSystemOwner)
        return Set(visible + protected + [ownBundle, "com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"])
            .sorted()
    }
}

@MainActor
final class NativeMenuBarVisibility {
    static var available: Bool { true }
    private let preferences = NativeMenuBarPreferences()
    private var hiddenBundles: Set<String>?
    private let recordingRestriction = RecordingIndicatorRestriction()
    private var restrictedFrames: [CGRect] = []
    private var lastBoundary: CGRect?
    private var recordingOnHiddenSide = false
    private var appliedPlan: NativeCollapsePlan?
    private var selectionDirty = true
    private let log = Logger(subsystem: "io.github.devnjw.LessBar", category: "nativeSelection")
    var needsPreferencesAccess: Bool { !preferences.hasAccess }
    func requestPreferencesAccess(_ completion: @escaping @MainActor (Bool) -> Void) {
        preferences.requestAccess(completion)
    }
    func markSelectionDirty() { selectionDirty = true }

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "nativeHiddenBundles") {
            hiddenBundles = Set(saved)
            selectionDirty = false
        }
        // Recover a previous interrupted session before selecting any new items.
        do { try preferences.restore(releaseOwnership: true) }
        catch { log.error("Native preference recovery requires attention: \(String(describing: error), privacy: .public)") }
    }
    private var generation = 0
    private(set) var pending = false
    private var hitTestItems: [NativeMenuBarItem] = []
    private var allowedBundles: Set<String>?
    // AX may retain rectangles for restricted icons. Only the current visible
    // identities occupy space; keep filtering at read time across transitions.
    var frames: [CGRect] {
        NativeMenuBarSelection.occupiedFrames(items: hitTestItems, allowedBundles: allowedBundles,
            restrictedFrames: restrictedFrames, restrictSystemItems: recordingRestriction.isActive)
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
                            let identity = id.lowercased().contains("textinput") || id.lowercased().contains("inputmenu")
                                ? NativeMenuBarPreferences.inputBundle : "com.apple.MenuBarAgent"
                            items.append(.init(bundle: identity, frame: CGRect(origin: point, size: size), identifier: id))
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
        let token = generation
        snapshot { [weak self] items in
            guard let self else { return }
            scanning = false
            scannedAt = ProcessInfo.processInfo.systemUptime
            guard generation == token, let primary = NSScreen.screens.first else { return }
            hitTestItems = items.map { .init(bundle: $0.bundle,
                frame: LayoutSafety.appKitFrame(fromWindowServer: $0.frame,
                    primaryScreenMaxY: primary.frame.maxY), identifier: $0.identifier) }
            if allowedBundles != nil, !pending, !recordingRestriction.isPending, let lastBoundary {
                applyVisibility(items: items, boundary: lastBoundary) { [weak self] succeeded in
                    if !succeeded { self?.log.error("Could not refresh the recording indicator restriction") }
                }
            }
        }
    }

    private func applyVisibility(items: [NativeMenuBarItem], boundary: CGRect,
                                            completion: @escaping @MainActor (Bool) -> Void) {
        guard let primary = NSScreen.screens.first else { completion(false); return }
        let screens = NSScreen.screens.map {
            LayoutSafety.appKitFrame(fromWindowServer: $0.frame, primaryScreenMaxY: primary.frame.maxY)
        }
        let observed = NativeMenuBarSelection.recordingIsOnHiddenSide(items: items, boundary: boundary,
            ownBundle: Bundle.main.bundleIdentifier ?? "io.github.devnjw.LessBar", screens: screens,
            leftToRight: NSApp.userInterfaceLayoutDirection == .leftToRight)
        if let observed { recordingOnHiddenSide = observed }
        // While a restriction is held the system may omit its own hidden item
        // from AX. Retain that decision until reveal restores the original item.
        let hide = observed ?? (recordingRestriction.isActive && recordingOnHiddenSide)
        if hide {
            let frames = items.filter {
                $0.identifier.map(NativeMenuBarSelection.restrictedSystemIdentifiers.contains) ?? false
            }.map { LayoutSafety.appKitFrame(fromWindowServer: $0.frame, primaryScreenMaxY: primary.frame.maxY) }
            if !frames.isEmpty { restrictedFrames = frames }
        }
        let hidden = hiddenBundles ?? []
        let visible = Set(items.map(\.bundle)).subtracting(hidden)
        let bundles = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            .union(items.map(\.bundle)).union(preferences.allBundleIdentities)
            .union([Bundle.main.bundleIdentifier ?? "io.github.devnjw.LessBar"])
        let exclusions = preferences.restrictionExclusions(hidden: hidden, visible: visible)
        let plan = NativeCollapsePlan(hidden: hidden, allBundles: bundles,
            resolvedHidden: exclusions, recordingOnHiddenSide: hide)
        if appliedPlan == plan && recordingRestriction.isActive == plan.restrictSystemItems {
            completion(true)
            return
        }
        let token = generation
        if plan.restrictSystemItems {
            // The assertion hides the apps and the original AV item in one
            // system reflow. Restore any old preference flags only afterwards,
            // while the assertion already keeps those apps off the bar.
            recordingRestriction.apply(hidden: true, allowing: plan.restrictionAllowedBundles) { [weak self] succeeded in
                guard let self, generation == token else { return }
                guard succeeded else { completion(false); return }
                do {
                    try preferences.hide(bundles: plan.preferenceHiddenBundles, keepingVisible: visible)
                    appliedPlan = plan
                    completion(true)
                } catch {
                    log.error("Could not apply single-transition hiding: \(String(describing: error), privacy: .public)")
                    completion(false)
                }
            }
        } else {
            do {
                // When switching away from a held assertion, establish the
                // preference hiding before releasing it, so apps never flash in.
                try preferences.hide(bundles: plan.preferenceHiddenBundles, keepingVisible: visible)
                recordingRestriction.release()
                appliedPlan = plan
                completion(true)
            } catch {
                log.error("Could not apply preference hiding: \(String(describing: error), privacy: .public)")
                completion(false)
            }
        }
    }

    func collapse(boundary: CGRect, completion: @escaping @MainActor (Bool) -> Void) {
        guard Self.available, AXIsProcessTrusted(), !pending else { completion(false); return }
        generation += 1
        let token = generation
        pending = true
        snapshot { [weak self] items in
            guard let self, self.generation == token else { return }
            // An empty inventory must never replace the saved section selection.
            guard !items.isEmpty, AXIsProcessTrusted() else {
                pending = false
                completion(false)
                return
            }
            let ownBundle = Bundle.main.bundleIdentifier ?? "io.github.devnjw.LessBar"
            // An unobserved divider must fail open instead of hiding the wrong apps.
            guard items.contains(where: { $0.bundle == ownBundle }),
                  let primary = NSScreen.screens.first else {
                pending = false
                completion(false)
                return
            }
            let screens = NSScreen.screens.map {
                LayoutSafety.appKitFrame(fromWindowServer: $0.frame,
                    primaryScreenMaxY: primary.frame.maxY)
            }
            let axBoundary = LayoutSafety.appKitFrame(fromWindowServer: boundary,
                primaryScreenMaxY: primary.frame.maxY)
            self.lastBoundary = axBoundary
            let measuredAllowed = NativeMenuBarSelection.allowed(items: items, boundary: axBoundary,
                ownBundle: ownBundle,
                leftToRight: NSApp.userInterfaceLayoutDirection == .leftToRight,
                screens: screens)
            if self.selectionDirty || self.hiddenBundles == nil {
                self.hiddenBundles = Set(items.map(\.bundle)).subtracting(measuredAllowed)
                self.selectionDirty = false
            }
            let hidden = self.hiddenBundles ?? []
            for item in items {
                self.log.info("Selection \(item.bundle, privacy: .public) frame=\(String(describing: item.frame), privacy: .public) identifier=\(item.identifier ?? "", privacy: .public) hidden=\(hidden.contains(item.bundle))")
            }
            UserDefaults.standard.set(hidden.sorted(), forKey: "nativeHiddenBundles")
            self.allowedBundles = Set(items.map(\.bundle)).subtracting(hidden)
            self.applyVisibility(items: items, boundary: axBoundary) { [weak self] succeeded in
                guard let self, generation == token else { return }
                pending = false
                if !succeeded { reveal() }
                completion(succeeded)
            }
        }
        // An unresponsive AX inventory cannot leave the UI stuck forever.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, self.generation == token, pending else { return }
            reveal()
            completion(false)
        }
    }

    @discardableResult
    func reveal(releaseOwnership: Bool = false) -> Bool {
        generation += 1
        pending = false
        recordingRestriction.release()
        appliedPlan = nil
        restrictedFrames = []
        do { try preferences.restore(releaseOwnership: releaseOwnership) }
        catch {
            log.error("Native reveal failed; recovery record retained: \(String(describing: error), privacy: .public)")
            return false
        }
        allowedBundles = nil
        scannedAt = -Double.infinity
        return true
    }
}
