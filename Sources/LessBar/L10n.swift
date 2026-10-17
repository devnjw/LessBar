import Foundation

/// Shared localized strings for AppKit and SwiftUI, bundled with the app.
enum L10n {
    // Prefer installed resources; SwiftPM lookup varies between toolchains.
    private static let bundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("LessBar_LessBar.bundle"),
           let bundled = Bundle(url: url) { return bundled }
        return .module
    }()
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
    static var showOnHover: String { text("showOnHover") }
    static var showOnHoverDetail: String { text("showOnHoverDetail") }
    static var timing: String { text("timing") }
    static var hoverDelay: String { text("hoverDelay") }
    static var autoRehide: String { text("autoRehide") }
    static var autoRehideDetail: String { text("autoRehideDetail") }
    static var autoRehideRequiredForHover: String { text("autoRehideRequiredForHover") }
    static var rehideDelay: String { text("rehideDelay") }
    static var temporaryShowAll: String { text("temporaryShowAll") }
    static var allowAccessibility: String { text("allowAccessibility") }
    static var accessibilityNeeded: String { text("accessibilityNeeded") }
    static func secondsFormat(_ value: Double) -> String {
        String(format: text("secondsFormat"), locale: Locale.current, value)
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
