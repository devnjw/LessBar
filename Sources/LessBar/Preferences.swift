import Foundation
import ServiceManagement

enum RehideStrategy: String, CaseIterable, Identifiable {
    case afterExit
    case timed

    var id: String { rawValue }
}

@MainActor
final class Preferences: ObservableObject {
    @Published var launchAtLogin = false
    @Published var loginMessage = ""

    @Published var showOnHover: Bool { didSet { save(showOnHover, for: .showOnHover) } }
    @Published var hoverDelay: Double { didSet { save(hoverDelay, for: .hoverDelay) } }
    @Published private var preferredAutoRehide: Bool {
        didSet { save(preferredAutoRehide, for: .autoRehide) }
    }
    @Published var rehideDelay: Double { didSet { save(rehideDelay, for: .rehideDelay) } }

    // Hover always re-hides without overwriting the choice used in chevron mode.
    var autoRehide: Bool {
        get { showOnHover || preferredAutoRehide }
        set {
            guard !showOnHover else { return }
            preferredAutoRehide = newValue
        }
    }

    // Core interactions are consistent even when upgrading from older settings.
    let showOnClick = false
    let rehideStrategy: RehideStrategy = .afterExit
    let showAllOnCommandDrag = true
    let hideApplicationMenus = false

    // Preserve existing placements and their context-menu recovery action. New
    // installs have only the normal hidden section; these are not new settings.
    let enableAlwaysHidden: Bool
    let temporaryShowDelay: Double

    private let defaults: UserDefaults

    func showsChevron(accessibilityGranted: Bool) -> Bool {
        !showOnHover || !accessibilityGranted
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showOnHover = defaults.object(forKey: Key.showOnHover.rawValue) as? Bool ?? false
        hoverDelay = Self.double(.hoverDelay, default: 0.2, in: defaults, range: 0...2)
        preferredAutoRehide = defaults.object(forKey: Key.autoRehide.rawValue) as? Bool ?? true
        rehideDelay = Self.double(.rehideDelay, default: 3, in: defaults, range: 0...10)
        enableAlwaysHidden = defaults.object(forKey: Key.enableAlwaysHidden.rawValue) as? Bool ?? false
        temporaryShowDelay = Self.double(.temporaryShowDelay, default: 15, in: defaults, range: 1...60)
    }

    /// Copy only our prototype's setup/placement keys, never overwrite new choices.
    /// Login-item registration belongs to the bundle identity and is not migrated.
    static func migratePrototypeSettings(
        from legacy: UserDefaults? = UserDefaults(suiteName: "local.tidybar.app"),
        to current: UserDefaults = .standard
    ) {
        guard let legacy, !current.bool(forKey: "didMigratePrototype") else { return }
        for key in ["hasShownSetup", "NSStatusItem Preferred Position TidyBar.Toggle",
                    "NSStatusItem Visible TidyBar.Toggle"] {
            if current.object(forKey: key) == nil, let value = legacy.object(forKey: key) {
                current.set(value, forKey: key)
            }
        }
        current.set(true, forKey: "didMigratePrototype")
    }

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginMessage = status == .requiresApproval ? L10n.loginApproval : ""
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
        } catch {
            refreshLoginStatus()
            loginMessage = String(format: L10n.loginFailed, error.localizedDescription)
        }
    }

    private func save(_ value: Any, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private static func double(_ key: Key, default fallback: Double,
                               in defaults: UserDefaults, range: ClosedRange<Double>) -> Double {
        guard defaults.object(forKey: key.rawValue) != nil else { return fallback }
        let stored = defaults.double(forKey: key.rawValue)
        guard stored.isFinite else { return fallback }
        return min(max(stored, range.lowerBound), range.upperBound)
    }

    private enum Key: String {
        case showOnHover = "lessbar.showOnHover"
        case hoverDelay = "lessbar.hoverDelay"
        case autoRehide = "lessbar.autoRehide"
        case rehideDelay = "lessbar.rehideDelay"
        case enableAlwaysHidden = "lessbar.enableAlwaysHidden"
        case temporaryShowDelay = "lessbar.temporaryShowDelay"
    }
}
