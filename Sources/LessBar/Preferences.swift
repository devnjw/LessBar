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

    @Published var showOnClick: Bool { didSet { save(showOnClick, for: .showOnClick) } }
    @Published var showOnHover: Bool { didSet { save(showOnHover, for: .showOnHover) } }
    @Published var hoverDelay: Double { didSet { save(hoverDelay, for: .hoverDelay) } }
    @Published var autoRehide: Bool { didSet { save(autoRehide, for: .autoRehide) } }
    @Published var rehideStrategy: RehideStrategy { didSet { save(rehideStrategy.rawValue, for: .rehideStrategy) } }
    @Published var rehideDelay: Double { didSet { save(rehideDelay, for: .rehideDelay) } }
    @Published var showSectionDividers: Bool { didSet { save(showSectionDividers, for: .showSectionDividers) } }
    @Published var showAllOnCommandDrag: Bool { didSet { save(showAllOnCommandDrag, for: .showAllOnCommandDrag) } }
    @Published var enableAlwaysHidden: Bool { didSet { save(enableAlwaysHidden, for: .enableAlwaysHidden) } }
    @Published var temporaryShowDelay: Double { didSet { save(temporaryShowDelay, for: .temporaryShowDelay) } }
    @Published var hideApplicationMenus: Bool { didSet { save(hideApplicationMenus, for: .hideApplicationMenus) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showOnClick = defaults.object(forKey: Key.showOnClick.rawValue) as? Bool ?? true
        showOnHover = defaults.object(forKey: Key.showOnHover.rawValue) as? Bool ?? true
        hoverDelay = Self.double(.hoverDelay, default: 0.2, in: defaults, range: 0...2)
        autoRehide = defaults.object(forKey: Key.autoRehide.rawValue) as? Bool ?? true
        rehideStrategy = RehideStrategy(rawValue: defaults.string(forKey: Key.rehideStrategy.rawValue) ?? "") ?? .afterExit
        rehideDelay = Self.double(.rehideDelay, default: 3, in: defaults, range: 0...10)
        showSectionDividers = defaults.object(forKey: Key.showSectionDividers.rawValue) as? Bool ?? false
        showAllOnCommandDrag = defaults.object(forKey: Key.showAllOnCommandDrag.rawValue) as? Bool ?? true
        enableAlwaysHidden = defaults.object(forKey: Key.enableAlwaysHidden.rawValue) as? Bool ?? false
        temporaryShowDelay = Self.double(.temporaryShowDelay, default: 15, in: defaults, range: 1...60)
        hideApplicationMenus = defaults.object(forKey: Key.hideApplicationMenus.rawValue) as? Bool ?? false
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
        case showOnClick = "lessbar.showOnClick"
        case showOnHover = "lessbar.showOnHover"
        case hoverDelay = "lessbar.hoverDelay"
        case autoRehide = "lessbar.autoRehide"
        case rehideStrategy = "lessbar.rehideStrategy"
        case rehideDelay = "lessbar.rehideDelay"
        case showSectionDividers = "lessbar.showSectionDividers"
        case showAllOnCommandDrag = "lessbar.showAllOnCommandDrag"
        case enableAlwaysHidden = "lessbar.enableAlwaysHidden"
        case temporaryShowDelay = "lessbar.temporaryShowDelay"
        case hideApplicationMenus = "lessbar.hideApplicationMenus"
    }
}
