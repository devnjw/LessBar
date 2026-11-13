import XCTest
@testable import LessBar

final class NativeCollapsePlanTests: XCTestCase {
    func testHiddenRecordingAndAppsUseOneRestrictionRatherThanTwoReflows() {
        let plan = NativeCollapsePlan(hidden: ["hidden.app", "com.apple.TextInputMenuAgent"],
            allBundles: ["hidden.app", "visible.app", "lessbar", "com.apple.TextInputMenuAgent"],
            resolvedHidden: ["hidden.app", "com.apple.TextInputMenuAgent"], recordingOnHiddenSide: true)
        XCTAssertTrue(plan.restrictSystemItems)
        XCTAssertFalse(plan.preferenceHiddenBundles.contains("hidden.app"),
            "Preference hiding must not animate the same app a second time")
        XCTAssertEqual(plan.preferenceHiddenBundles, ["com.apple.TextInputMenuAgent"])
        XCTAssertEqual(plan.restrictionAllowedBundles, ["visible.app", "lessbar"])
    }

    func testVisibleRecordingUsesOnlyPreferenceHidingForApps() {
        let plan = NativeCollapsePlan(hidden: ["hidden.app"],
            allBundles: ["hidden.app", "visible.app"], resolvedHidden: ["hidden.app"],
            recordingOnHiddenSide: false)
        XCTAssertFalse(plan.restrictSystemItems)
        XCTAssertEqual(plan.preferenceHiddenBundles, ["hidden.app"])
    }
}
