import XCTest
@testable import LessBar

final class PreferencesMigrationTests: XCTestCase {
    @MainActor func testFeaturePreferencesUseApprovedDefaultsAndPersist() throws {
        let suite = "LessBarTests.preferences.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let initial = Preferences(defaults: defaults)
        XCTAssertTrue(initial.showOnClick)
        XCTAssertTrue(initial.showOnHover)
        XCTAssertEqual(initial.hoverDelay, 0.2, accuracy: 0.0001)
        XCTAssertTrue(initial.autoRehide)
        XCTAssertEqual(initial.rehideStrategy, .afterExit)
        XCTAssertEqual(initial.rehideDelay, 3)
        XCTAssertFalse(initial.showSectionDividers)
        XCTAssertTrue(initial.showAllOnCommandDrag)
        XCTAssertFalse(initial.enableAlwaysHidden)
        XCTAssertEqual(initial.temporaryShowDelay, 15)
        XCTAssertFalse(initial.hideApplicationMenus)

        initial.showOnClick = false
        initial.showOnHover = false
        initial.hoverDelay = 0.8
        initial.autoRehide = false
        initial.rehideStrategy = .timed
        initial.rehideDelay = 9
        initial.showSectionDividers = true
        initial.showAllOnCommandDrag = false
        initial.enableAlwaysHidden = true
        initial.temporaryShowDelay = 22
        initial.hideApplicationMenus = true

        let restored = Preferences(defaults: defaults)
        XCTAssertFalse(restored.showOnClick)
        XCTAssertFalse(restored.showOnHover)
        XCTAssertEqual(restored.hoverDelay, 0.8, accuracy: 0.0001)
        XCTAssertFalse(restored.autoRehide)
        XCTAssertEqual(restored.rehideStrategy, .timed)
        XCTAssertEqual(restored.rehideDelay, 9)
        XCTAssertTrue(restored.showSectionDividers)
        XCTAssertFalse(restored.showAllOnCommandDrag)
        XCTAssertTrue(restored.enableAlwaysHidden)
        XCTAssertEqual(restored.temporaryShowDelay, 22)
        XCTAssertTrue(restored.hideApplicationMenus)
    }

    @MainActor func testDelayPreferencesAreClampedToControlRanges() throws {
        let suite = "LessBarTests.preferences.range.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(-3.0, forKey: "lessbar.hoverDelay")
        defaults.set(80.0, forKey: "lessbar.rehideDelay")
        defaults.set(0.0, forKey: "lessbar.temporaryShowDelay")

        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.hoverDelay, 0)
        XCTAssertEqual(preferences.rehideDelay, 10)
        XCTAssertEqual(preferences.temporaryShowDelay, 1)
    }

    @MainActor func testZeroAndFractionalRehideDelaysPersist() throws {
        let suite = "LessBarTests.preferences.fractional.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.rehideDelay = 0
        XCTAssertEqual(Preferences(defaults: defaults).rehideDelay, 0)
        preferences.rehideDelay = 0.1
        XCTAssertEqual(Preferences(defaults: defaults).rehideDelay, 0.1, accuracy: 0.0001)
        defaults.set(-1.0, forKey: "lessbar.rehideDelay")
        XCTAssertEqual(Preferences(defaults: defaults).rehideDelay, 0)
    }

    @MainActor func testNonFiniteDelayPreferencesUseDefaults() throws {
        let suite = "LessBarTests.preferences.nonfinite.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Double.nan, forKey: "lessbar.hoverDelay")
        defaults.set(Double.infinity, forKey: "lessbar.rehideDelay")
        defaults.set(-Double.infinity, forKey: "lessbar.temporaryShowDelay")

        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.hoverDelay, 0.2, accuracy: 0.0001)
        XCTAssertEqual(preferences.rehideDelay, 3)
        XCTAssertEqual(preferences.temporaryShowDelay, 15)
    }

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
