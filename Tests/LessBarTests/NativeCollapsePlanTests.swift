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

    func testFullscreenDefersGlobalRestrictionButKeepsOrdinaryIconsHidden() {
        let plan = NativeCollapsePlan(hidden: ["hidden.app", "com.apple.TextInputMenuAgent"],
            allBundles: ["hidden.app", "visible.app", "lessbar", "com.apple.TextInputMenuAgent"],
            resolvedHidden: ["hidden.app", "com.apple.TextInputMenuAgent"],
            recordingOnHiddenSide: true, systemRestrictionEnabled: false)
        XCTAssertFalse(plan.restrictSystemItems)
        XCTAssertEqual(plan.preferenceHiddenBundles, ["hidden.app", "com.apple.TextInputMenuAgent"])
    }

    func testAXFullscreenWindowMustMatchItsVisibleWindowServerFrame() {
        let fullscreenFrame = CGRect(x: 0, y: 33, width: 1728, height: 1084)
        XCTAssertTrue(FullscreenWindowVisibility.matchesVisibleWindow(
            fullscreenFrame: fullscreenFrame, visibleFrame: fullscreenFrame))
        XCTAssertFalse(FullscreenWindowVisibility.matchesVisibleWindow(
            fullscreenFrame: fullscreenFrame,
            visibleFrame: CGRect(x: 20, y: 70, width: 1688, height: 1000)))
    }

    func testFullscreenCanReuseOnlyAnUndirtySavedSelection() {
        XCTAssertTrue(NativeCollapsePlan.canReuseSavedSelection(fullscreenWindowVisible: true,
            selectionDirty: false, hasSavedSelection: true))
        XCTAssertFalse(NativeCollapsePlan.canReuseSavedSelection(fullscreenWindowVisible: false,
            selectionDirty: false, hasSavedSelection: true))
        XCTAssertFalse(NativeCollapsePlan.canReuseSavedSelection(fullscreenWindowVisible: true,
            selectionDirty: true, hasSavedSelection: true))
        XCTAssertFalse(NativeCollapsePlan.canReuseSavedSelection(fullscreenWindowVisible: true,
            selectionDirty: false, hasSavedSelection: false))
    }

}
