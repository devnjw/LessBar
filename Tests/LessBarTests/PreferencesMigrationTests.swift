import XCTest
@testable import LessBar

final class PreferencesMigrationTests: XCTestCase {
    @MainActor func testFeaturePreferencesUseApprovedDefaultsAndPersist() throws {
        let suite = "LessBarTests.preferences.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let initial = Preferences(defaults: defaults)
        XCTAssertFalse(initial.showOnClick)
        XCTAssertFalse(initial.showOnHover)
        XCTAssertEqual(initial.hoverDelay, 0.2, accuracy: 0.0001)
        XCTAssertTrue(initial.autoRehide)
        XCTAssertEqual(initial.rehideStrategy, .afterExit)
        XCTAssertEqual(initial.rehideDelay, 3)
        XCTAssertTrue(initial.showsChevron(accessibilityGranted: true))
        XCTAssertTrue(initial.showAllOnCommandDrag)
        XCTAssertFalse(initial.enableAlwaysHidden)
        XCTAssertEqual(initial.temporaryShowDelay, 15)
        XCTAssertFalse(initial.hideApplicationMenus)

        initial.autoRehide = false
        initial.showOnHover = true
        initial.hoverDelay = 0.8
        initial.rehideDelay = 9

        let restored = Preferences(defaults: defaults)
        XCTAssertFalse(restored.showOnClick)
        XCTAssertTrue(restored.showOnHover)
        XCTAssertEqual(restored.hoverDelay, 0.8, accuracy: 0.0001)
        XCTAssertTrue(restored.autoRehide)
        XCTAssertEqual(restored.rehideStrategy, .afterExit)
        XCTAssertEqual(restored.rehideDelay, 9)
        XCTAssertTrue(restored.showsChevron(accessibilityGranted: true))
        XCTAssertTrue(restored.showAllOnCommandDrag)
        XCTAssertFalse(restored.enableAlwaysHidden)
        XCTAssertEqual(restored.temporaryShowDelay, 15)
        XCTAssertFalse(restored.hideApplicationMenus)
    }

    @MainActor func testUpgradeKeepsUserChoicesAndLegacyHiddenSectionRecoverable() throws {
        let suite = "LessBarTests.preferences.upgrade.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "lessbar.showOnHover")
        defaults.set(false, forKey: "lessbar.autoRehide")
        defaults.set(0.7, forKey: "lessbar.hoverDelay")
        defaults.set(5.2, forKey: "lessbar.rehideDelay")
        defaults.set(true, forKey: "lessbar.enableAlwaysHidden")
        defaults.set(22.0, forKey: "lessbar.temporaryShowDelay")
        defaults.set(160.0, forKey: "NSStatusItem Preferred Position LessBar.AlwaysHidden")
        defaults.set(true, forKey: "lessbar.showOnClick")
        defaults.set("timed", forKey: "lessbar.rehideStrategy")
        defaults.set(false, forKey: "lessbar.showSectionDividers")
        defaults.set(false, forKey: "lessbar.showAllOnCommandDrag")
        defaults.set(true, forKey: "lessbar.hideApplicationMenus")

        let upgraded = Preferences(defaults: defaults)
        XCTAssertTrue(upgraded.showOnHover)
        XCTAssertTrue(upgraded.autoRehide)
        XCTAssertFalse(defaults.bool(forKey: "lessbar.autoRehide"))
        XCTAssertEqual(upgraded.hoverDelay, 0.7, accuracy: 0.0001)
        XCTAssertEqual(upgraded.rehideDelay, 5.2, accuracy: 0.0001)
        XCTAssertTrue(upgraded.enableAlwaysHidden)
        XCTAssertEqual(upgraded.temporaryShowDelay, 22)
        XCTAssertEqual(defaults.double(forKey: "NSStatusItem Preferred Position LessBar.AlwaysHidden"), 160)
        XCTAssertFalse(upgraded.showOnClick)
        XCTAssertEqual(upgraded.rehideStrategy, .afterExit)
        XCTAssertFalse(upgraded.showsChevron(accessibilityGranted: true))
        XCTAssertTrue(upgraded.showsChevron(accessibilityGranted: false))
        XCTAssertTrue(upgraded.showAllOnCommandDrag)
        XCTAssertFalse(upgraded.hideApplicationMenus)
        // Retired values are left intact for rollback, but cannot hide the
        // permission fallback, disable rearranging, or activate another app's menus.
        XCTAssertTrue(defaults.bool(forKey: "lessbar.hideApplicationMenus"))
        XCTAssertEqual(defaults.string(forKey: "lessbar.rehideStrategy"), "timed")
    }

    @MainActor func testChevronIsIndependentAndReturnsWhenPermissionIsLost() throws {
        let suite = "LessBarTests.preferences.chevron.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: false))
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: true))
        preferences.showOnHover = true
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: true))
        preferences.showChevron = false
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: false))
        XCTAssertFalse(preferences.showsChevron(accessibilityGranted: true))
        // Revocation must restore the control without clearing the user's choice.
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: false))
        XCTAssertTrue(preferences.showOnHover)
        preferences.showChevron = true
        preferences.showOnHover = false
        XCTAssertTrue(preferences.showsChevron(accessibilityGranted: true))
    }

    @MainActor func testHoverRequiresAutomaticHidingAndRestoresChoiceAcrossRelaunch() throws {
        for previousChoice in [false, true] {
            let suite = "LessBarTests.preferences.hoverRehide.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let preferences = Preferences(defaults: defaults)
            preferences.autoRehide = previousChoice
            preferences.rehideDelay = 3.4

            preferences.showOnHover = true
            XCTAssertTrue(preferences.autoRehide)
            // Even a stale binding cannot disable automatic hiding in hover mode.
            preferences.autoRehide = false
            XCTAssertTrue(preferences.autoRehide)
            XCTAssertEqual(defaults.bool(forKey: "lessbar.autoRehide"), previousChoice)

            preferences.showOnHover = false
            XCTAssertEqual(preferences.autoRehide, previousChoice)
            preferences.showOnHover = true
            let relaunched = Preferences(defaults: defaults)
            XCTAssertTrue(relaunched.autoRehide)
            relaunched.showOnHover = false
            XCTAssertEqual(relaunched.autoRehide, previousChoice)
            XCTAssertEqual(relaunched.rehideDelay, 3.4, accuracy: 0.0001)
        }
    }

    @MainActor func testHiddenChevronKeepsARevealMethodAndRestoresManualHideChoice() throws {
        let suite = "LessBarTests.preferences.revealMethods.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.autoRehide = false
        preferences.showChevron = false
        XCTAssertTrue(preferences.showOnClick) // Safe fallback when both were off.
        XCTAssertFalse(preferences.showOnHover)
        XCTAssertTrue(preferences.autoRehide)
        preferences.showOnClick = false
        XCTAssertTrue(preferences.showOnClick) // Cannot remove the final method.
        preferences.showOnHover = true
        preferences.showOnClick = false
        XCTAssertTrue(preferences.showOnHover)
        XCTAssertFalse(preferences.showOnClick)
        preferences.showOnHover = false
        XCTAssertTrue(preferences.showOnHover)
        preferences.showOnClick = true
        preferences.showOnHover = false
        let relaunched = Preferences(defaults: defaults)
        XCTAssertFalse(relaunched.showChevron)
        XCTAssertTrue(relaunched.showOnClick)
        XCTAssertFalse(relaunched.showOnHover)
        relaunched.showChevron = true
        relaunched.showOnClick = false
        XCTAssertFalse(relaunched.showOnHover)
        XCTAssertFalse(relaunched.showOnClick)
        XCTAssertFalse(relaunched.autoRehide)
    }

    @MainActor func testAllStoredRevealCombinationsRemainReachableAfterRelaunch() throws {
        for chevron in [false, true] {
            for hover in [false, true] {
                for click in [false, true] {
                    let suite = "LessBarTests.preferences.combinations.\(UUID())"
                    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
                    defer { defaults.removePersistentDomain(forName: suite) }
                    defaults.set(chevron, forKey: "lessbar.showChevron")
                    defaults.set(hover, forKey: "lessbar.showOnHover")
                    defaults.set(click, forKey: "lessbar.emptySpaceClick")
                    let preferences = Preferences(defaults: defaults)
                    XCTAssertEqual(preferences.showChevron, chevron)
                    XCTAssertEqual(preferences.showOnHover, hover)
                    XCTAssertEqual(preferences.showOnClick, click || (!chevron && !hover))
                    XCTAssertTrue(preferences.showChevron || preferences.showOnHover || preferences.showOnClick)
                    XCTAssertTrue(preferences.showsChevron(accessibilityGranted: false))
                    let restored = Preferences(defaults: defaults)
                    XCTAssertEqual(restored.showOnClick, preferences.showOnClick)
                    XCTAssertEqual(restored.showChevron, preferences.showChevron)
                }
            }
        }
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
