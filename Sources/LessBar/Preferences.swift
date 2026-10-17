import Foundation
import ServiceManagement

enum RehideStrategy: String, CaseIterable, Identifiable {
    case afterExit
    case timed

    var id: String { rawValue }
}

@MainActor
final class Preferences: ObservableObject {
    var onLanguageChange: ((AppLanguage) -> Void)?
    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            defaults.set(language.rawValue, forKey: AppLanguage.preferenceKey)
            onLanguageChange?(oldValue)
        }
    }
    @Published var launchAtLogin = false
    @Published var loginMessage = ""

    private struct RevealOptions {
        var chevron: Bool
        var hover: Bool
        var click: Bool
    }
    @Published private var revealOptions: RevealOptions

    var showChevron: Bool {
        get { revealOptions.chevron }
        set {
            var options = revealOptions
            options.chevron = newValue
            if !newValue && !options.hover && !options.click { options.click = true }
            updateRevealOptions(options)
        }
    }
    var showOnHover: Bool {
        get { revealOptions.hover }
        set {
            guard newValue || canDisableHover else { return }
            var options = revealOptions
            options.hover = newValue
            updateRevealOptions(options)
        }
    }
    var showOnClick: Bool {
        get { revealOptions.click }
        set {
            guard newValue || canDisableClick else { return }
            var options = revealOptions
            options.click = newValue
            updateRevealOptions(options)
        }
    }
    var canDisableHover: Bool { showChevron || showOnClick }
    var canDisableClick: Bool { showChevron || showOnHover }
    var requiresAutoRehide: Bool { showOnHover || !showChevron }

    private func updateRevealOptions(_ options: RevealOptions) {
        // Publish a valid combination atomically, including click fallback.
        revealOptions = options
        save(options.chevron, for: .showChevron)
        save(options.hover, for: .showOnHover)
        save(options.click, for: .showOnClick)
    }
    @Published var hoverDelay: Double { didSet { save(hoverDelay, for: .hoverDelay) } }
    @Published private var preferredAutoRehide: Bool {
        didSet { save(preferredAutoRehide, for: .autoRehide) }
    }
    @Published var rehideDelay: Double { didSet { save(rehideDelay, for: .rehideDelay) } }

    // Hover and hidden-chevron modes re-hide without overwriting the manual choice.
    var autoRehide: Bool {
        get { requiresAutoRehide || preferredAutoRehide }
        set {
            guard !requiresAutoRehide else { return }
            preferredAutoRehide = newValue
        }
    }

    // Core interactions are consistent even when upgrading from older settings.
    let rehideStrategy: RehideStrategy = .afterExit
    let showAllOnCommandDrag = true
    let hideApplicationMenus = false

    // Preserve existing placements and their context-menu recovery action. New
    // installs have only the normal hidden section; these are not new settings.
    let enableAlwaysHidden: Bool
    let temporaryShowDelay: Double

    private let defaults: UserDefaults

    func showsChevron(accessibilityGranted: Bool) -> Bool {
        showChevron || !accessibilityGranted
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: AppLanguage.preferenceKey) ?? "") ?? .system
        let hover = defaults.object(forKey: Key.showOnHover.rawValue) as? Bool ?? false
        // Keep the previous release's appearance on first upgrade. Use a new
        // click key so a retired prototype setting cannot silently turn it on.
        let chevron = defaults.object(forKey: Key.showChevron.rawValue) as? Bool ?? !hover
        let click = defaults.object(forKey: Key.showOnClick.rawValue) as? Bool ?? false
        revealOptions = RevealOptions(chevron: chevron, hover: hover,
            click: click || (!chevron && !hover))
        hoverDelay = Self.double(.hoverDelay, default: 0.2, in: defaults, range: 0...2)
        preferredAutoRehide = defaults.object(forKey: Key.autoRehide.rawValue) as? Bool ?? true
        rehideDelay = Self.double(.rehideDelay, default: 3, in: defaults, range: 0...10)
        enableAlwaysHidden = defaults.object(forKey: Key.enableAlwaysHidden.rawValue) as? Bool ?? false
        temporaryShowDelay = Self.double(.temporaryShowDelay, default: 15, in: defaults, range: 1...60)
        updateRevealOptions(revealOptions)
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
        case showChevron = "lessbar.showChevron"
        case showOnClick = "lessbar.emptySpaceClick"
        case showOnHover = "lessbar.showOnHover"
        case hoverDelay = "lessbar.hoverDelay"
        case autoRehide = "lessbar.autoRehide"
        case rehideDelay = "lessbar.rehideDelay"
        case enableAlwaysHidden = "lessbar.enableAlwaysHidden"
        case temporaryShowDelay = "lessbar.temporaryShowDelay"
    }
}
