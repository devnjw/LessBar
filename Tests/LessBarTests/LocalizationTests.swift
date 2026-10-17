import XCTest
@testable import LessBar

final class LocalizationTests: XCTestCase {
    func testExplicitLanguagesAndSystemFallback() {
        XCTAssertEqual(L10n.resolvedLanguage(.english, preferredLanguages: ["ko-KR"]), "en")
        XCTAssertEqual(L10n.resolvedLanguage(.korean, preferredLanguages: ["en-US"]), "ko")
        XCTAssertEqual(L10n.resolvedLanguage(.system, preferredLanguages: ["ko-KR", "en"]), "ko")
        XCTAssertEqual(L10n.resolvedLanguage(.system, preferredLanguages: ["fr-FR", "en"]), "en")
        XCTAssertEqual(L10n.text("showChevron", language: .english), "Show Arrow")
        XCTAssertEqual(L10n.text("showChevron", language: .korean), "화살표 표시")
        XCTAssertEqual(L10n.text("settingsTitle", language: .korean), "Less Bar 설정")
        XCTAssertEqual(L10n.text("quit", language: .english), "Quit Less Bar")
    }

    @MainActor func testLanguagePersistsAndCallbackReadsTheSavedValue() throws {
        let suite = "LessBarTests.language.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.language, .system)
        var previousLanguages: [AppLanguage] = []
        preferences.onLanguageChange = { previous in
            previousLanguages.append(previous)
            XCTAssertEqual(defaults.string(forKey: AppLanguage.preferenceKey), preferences.language.rawValue)
        }
        for language in [AppLanguage.korean, .english, .system] {
            preferences.language = language
            XCTAssertEqual(Preferences(defaults: defaults).language, language)
        }
        XCTAssertEqual(previousLanguages, [.system, .korean, .english])
        preferences.language = .system
        XCTAssertEqual(previousLanguages.count, 3)
        preferences.onLanguageChange = nil
        defaults.set("invalid", forKey: AppLanguage.preferenceKey)
        XCTAssertEqual(Preferences(defaults: defaults).language, .system)
    }
}
