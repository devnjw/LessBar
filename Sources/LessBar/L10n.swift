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
    static var guideTitle: String { text("guideTitle") }
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
    static var settingsTabs: String { text("settingsTabs") }
    static var generalTab: String { text("generalTab") }
    static var advancedTab: String { text("advancedTab") }
    static var showOnClick: String { text("showOnClick") }
    static var showOnClickDetail: String { text("showOnClickDetail") }
    static var showOnHover: String { text("showOnHover") }
    static var showOnHoverDetail: String { text("showOnHoverDetail") }
    static var hoverDelay: String { text("hoverDelay") }
    static var autoRehide: String { text("autoRehide") }
    static var autoRehideDetail: String { text("autoRehideDetail") }
    static var rehideStrategy: String { text("rehideStrategy") }
    static var afterExitStrategy: String { text("afterExitStrategy") }
    static var timedStrategy: String { text("timedStrategy") }
    static var rehideDelay: String { text("rehideDelay") }
    static var showSectionDividers: String { text("showSectionDividers") }
    static var showSectionDividersDetail: String { text("showSectionDividersDetail") }
    static var showAllOnCommandDrag: String { text("showAllOnCommandDrag") }
    static var showAllOnCommandDragDetail: String { text("showAllOnCommandDragDetail") }
    static var enableAlwaysHidden: String { text("enableAlwaysHidden") }
    static var enableAlwaysHiddenDetail: String { text("enableAlwaysHiddenDetail") }
    static var temporaryShowDelay: String { text("temporaryShowDelay") }
    static var temporaryShowAll: String { text("temporaryShowAll") }
    static var hideApplicationMenus: String { text("hideApplicationMenus") }
    static var hideApplicationMenusDetail: String { text("hideApplicationMenusDetail") }
    static var allowAccessibility: String { text("allowAccessibility") }
    static var accessibilityNeeded: String { text("accessibilityNeeded") }
    static func secondsFormat(_ value: Double) -> String {
        String(format: text("secondsFormat"), locale: Locale.current, value)
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
