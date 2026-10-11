import XCTest
@testable import LessBar

final class PreferencesMigrationTests: XCTestCase {
    @MainActor func testMigrationPreservesCurrentChoicesAndIgnoresUnrelatedKeys() throws {
        let legacyName = "LessBarTests.legacy.\(UUID())"
        let currentName = "LessBarTests.current.\(UUID())"
        let legacy = try XCTUnwrap(UserDefaults(suiteName: legacyName))
        let current = try XCTUnwrap(UserDefaults(suiteName: currentName))
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            current.removePersistentDomain(forName: currentName)
        }
        legacy.set(true, forKey: "hasShownSetup")
        legacy.set(240.0, forKey: "NSStatusItem Preferred Position TidyBar.Toggle")
        legacy.set("unrelated", forKey: "otherSetting")
        current.set(false, forKey: "hasShownSetup")
        Preferences.migratePrototypeSettings(from: legacy, to: current)
        XCTAssertFalse(current.bool(forKey: "hasShownSetup"))
        XCTAssertEqual(current.double(forKey: "NSStatusItem Preferred Position TidyBar.Toggle"), 240)
        XCTAssertNil(current.object(forKey: "otherSetting"))
        current.removeObject(forKey: "NSStatusItem Preferred Position TidyBar.Toggle")
        Preferences.migratePrototypeSettings(from: legacy, to: current)
        XCTAssertNil(current.object(forKey: "NSStatusItem Preferred Position TidyBar.Toggle"))
    }
}
