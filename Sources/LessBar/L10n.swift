import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", korean = "ko"
    var id: String { rawValue }
    static let preferenceKey = "lessbar.language"
}

/// Shared localized strings for AppKit and SwiftUI, bundled with the app.
enum L10n {
    static let appName = "Less Bar"
    // Prefer installed resources; SwiftPM lookup varies between toolchains.
    private static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("LessBar_LessBar.bundle"),
           let bundled = Bundle(url: url) { return bundled }
        return .module
    }()
    static var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "") ?? .system
    }
    static func resolvedLanguage(_ language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if language != .system { return language.rawValue }
        return Bundle.preferredLocalizations(from: ["en", "ko"], forPreferences: preferredLanguages).first ?? "en"
    }
    private static let languageBundles: [String: Bundle] = {
        Dictionary(uniqueKeysWithValues: ["en", "ko"].compactMap { language in
            guard let path = bundle.path(forResource: language, ofType: "lproj"),
                  let localized = Bundle(path: path) else { return nil }
            return (language, localized)
        })
    }()
    static var language: String { text("language") }
    static var systemLanguage: String { text("systemLanguage") }
    static var boundaryOrder: String { text("boundaryOrder") }
    static var sharingPlacementFailed: String { text("sharingPlacementFailed") }
    static var settings: String { text("settings") }
    static var settingsTitle: String { text("settingsTitle") }
    static var quit: String { text("quit") }
    static var hideIcons: String { text("hideIcons") }
    static var showIcons: String { text("showIcons") }
    static var recoveryTitle: String { text("recoveryTitle") }
    static var toggleTooltip: String { text("toggleTooltip") }
    static var recoveryTooltip: String { text("recoveryTooltip") }
    static var positionUnavailable: String { text("positionUnavailable") }
    static var positionRecovery: String { text("positionRecovery") }
    static var ok: String { text("ok") }
    static var dragInstruction: String { text("dragInstruction") }
    static var launchAtLogin: String { text("launchAtLogin") }
    static var unsupported: String { text("unsupported") }
    static var hiddenIcons: String { text("hiddenIcons") }
    static var visibleIcons: String { text("visibleIcons") }
    static var guideAccessibility: String { text("guideAccessibility") }
    static var collapsed: String { text("collapsed") }
    static var expanded: String { text("expanded") }
    static var loginApproval: String { text("loginApproval") }
    static var loginFailed: String { text("loginFailed") }
    static var showChevron: String { text("showChevron") }
    static var showOnClick: String { text("showOnClick") }
    static var showOnClickDetail: String { text("showOnClickDetail") }
    static func settingInformation(_ title: String) -> String {
        String(format: text("settingInformation"), title)
    }
    static var revealRequired: String { text("revealRequired") }
    static var howToUse: String { text("howToUse") }
    static var arrangeIcons: String { text("arrangeIcons") }
    static var revealIcons: String { text("revealIcons") }
    static var guideHoverAndClick: String { text("guideHoverAndClick") }
    static var guideHover: String { text("guideHover") }
    static var guideClick: String { text("guideClick") }
    static var guideChevron: String { text("guideChevron") }
    static var showOnHover: String { text("showOnHover") }
    static var showOnHoverDetail: String { text("showOnHoverDetail") }
    static var advanced: String { text("advanced") }
    static var timing: String { text("timing") }
    static var hoverDelay: String { text("hoverDelay") }
    static var autoRehide: String { text("autoRehide") }
    static var autoRehideDetail: String { text("autoRehideDetail") }
    static var autoRehideRequired: String { text("autoRehideRequired") }
    static var rehideDelay: String { text("rehideDelay") }
    static var temporaryShowAll: String { text("temporaryShowAll") }
    static var allowAccessibility: String { text("allowAccessibility") }
    static var accessibilityNeeded: String { text("accessibilityNeeded") }
    static func secondsFormat(_ value: Double) -> String {
        String(format: text("secondsFormat"), locale: Locale.current, value)
    }

    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let selected = resolvedLanguage(language ?? selectedLanguage)
        let localized = languageBundles[selected] ?? bundle
        return localized.localizedString(forKey: key, value: nil, table: nil)
    }
}
