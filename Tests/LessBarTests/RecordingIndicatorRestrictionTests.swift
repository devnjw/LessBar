import XCTest
@testable import LessBar

final class RecordingIndicatorRestrictionTests: XCTestCase {
    private func item(_ bundle: String, x: CGFloat, id: String? = nil) -> NativeMenuBarItem {
        .init(bundle: bundle, frame: CGRect(x: x, y: 3.5, width: 24, height: 24), identifier: id)
    }

    func testRecordedAXPlacementHidesOnLeftAndPreservesOnRight() {
        let boundary = CGRect(x: 3446.5, y: 3.5, width: 2, height: 24)
        let screens = [CGRect(x: 1920, y: 0, width: 1920, height: 1080)]
        let divider = NativeMenuBarItem(bundle: "lessbar", frame: boundary)
        func hidden(_ x: CGFloat) -> Bool? {
            NativeMenuBarSelection.recordingIsOnHiddenSide(items: [divider,
                item("com.apple.MenuBarAgent", x: x, id: NativeMenuBarSelection.recordingIdentifier)],
                boundary: boundary, ownBundle: "lessbar", screens: screens, leftToRight: true)
        }
        XCTAssertEqual(hidden(3413), true)
        XCTAssertEqual(hidden(3500), false)
        XCTAssertNil(NativeMenuBarSelection.recordingIsOnHiddenSide(items: [divider],
            boundary: boundary, ownBundle: "lessbar", screens: screens, leftToRight: true))
    }

    func testRecordingSelectionUsesEditedDisplayAndFailsOpenWithoutDivider() {
        let first = CGRect(x: 400, y: 3.5, width: 24, height: 24)
        let second = CGRect(x: 1400, y: 3.5, width: 24, height: 24)
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]
        let items = [NativeMenuBarItem(bundle: "lessbar", frame: first),
            NativeMenuBarItem(bundle: "lessbar", frame: second),
            item("com.apple.MenuBarAgent", x: 300, id: NativeMenuBarSelection.recordingIdentifier),
            item("com.apple.MenuBarAgent", x: 1500, id: NativeMenuBarSelection.recordingIdentifier)]
        XCTAssertEqual(NativeMenuBarSelection.recordingIsOnHiddenSide(items: items,
            boundary: second, ownBundle: "lessbar", screens: screens, leftToRight: true), false)
        XCTAssertNil(NativeMenuBarSelection.recordingIsOnHiddenSide(items: Array(items.dropFirst(2)),
            boundary: second, ownBundle: "lessbar", screens: screens, leftToRight: true))
    }

    func testHiddenSystemAreaRevealsButClockRemainsProtected() {
        let av = item("com.apple.MenuBarAgent", x: 300, id: NativeMenuBarSelection.recordingIdentifier)
        let duplicate = item("com.apple.MenuBarAgent", x: 300)
        let clock = item("com.apple.MenuBarAgent", x: 500, id: "com.apple.menuextra.clock")
        let items = [av, duplicate, clock]
        XCTAssertEqual(NativeMenuBarSelection.occupiedFrames(items: items,
            allowedBundles: ["com.apple.MenuBarAgent"], restrictedFrames: [av.frame],
            restrictSystemItems: true), [clock.frame])
        XCTAssertEqual(NativeMenuBarSelection.occupiedFrames(items: items,
            allowedBundles: nil, restrictedFrames: [], restrictSystemItems: false).count, 3)
    }

    @MainActor func testRevealCancelsLateActivationAndDoesNotLeaveOriginalHidden() {
        var callback: RecordingIndicatorRestriction.Completion?
        var invalidated: [ObjectIdentifier] = []
        let restriction = RecordingIndicatorRestriction(activate: { _, result in callback = result },
            invalidate: { invalidated.append(ObjectIdentifier($0)) })
        var completed: [Bool] = []
        restriction.apply(hidden: true, allowing: ["app"]) { completed.append($0) }
        XCTAssertTrue(restriction.isPending)
        restriction.apply(hidden: false, allowing: []) { completed.append($0) }
        let late = NSObject()
        callback?(late, true)
        XCTAssertFalse(restriction.isActive)
        XCTAssertFalse(restriction.isPending)
        XCTAssertEqual(invalidated, [ObjectIdentifier(late)])
        XCTAssertEqual(completed, [true])
    }

    @MainActor func testRightSideNeverActivatesAndLeftSideReleasesOnReveal() {
        var callbacks: [RecordingIndicatorRestriction.Completion] = []
        var invalidated: [ObjectIdentifier] = []
        var allowedLists: [[String]] = []
        let restriction = RecordingIndicatorRestriction(activate: { bundles, result in
            allowedLists.append(bundles); callbacks.append(result)
        }, invalidate: { invalidated.append(ObjectIdentifier($0)) })
        restriction.apply(hidden: false, allowing: ["visible"]) { XCTAssertTrue($0) }
        XCTAssertTrue(callbacks.isEmpty)
        restriction.apply(hidden: true, allowing: ["visible", "helper"]) { XCTAssertTrue($0) }
        let held = NSObject()
        callbacks[0](held, true)
        XCTAssertTrue(restriction.isActive)
        restriction.apply(hidden: true, allowing: ["helper", "visible"]) { XCTAssertTrue($0) }
        XCTAssertEqual(callbacks.count, 1, "Identical polls must not reactivate the restriction")
        restriction.apply(hidden: false, allowing: []) { XCTAssertTrue($0) }
        XCTAssertEqual(invalidated, [ObjectIdentifier(held)])
        XCTAssertFalse(restriction.isActive)
        XCTAssertEqual(Set(allowedLists[0]), ["visible", "helper"])
    }

    @MainActor func testNewAppAllowListSwapsWithoutDroppingOldAssertionFirst() {
        var callbacks: [RecordingIndicatorRestriction.Completion] = []
        var invalidated: [ObjectIdentifier] = []
        let restriction = RecordingIndicatorRestriction(activate: { _, result in callbacks.append(result) },
            invalidate: { invalidated.append(ObjectIdentifier($0)) })
        restriction.apply(hidden: true, allowing: ["existing"]) { XCTAssertTrue($0) }
        let old = NSObject()
        callbacks[0](old, true)
        restriction.apply(hidden: true, allowing: ["existing", "new"]) { XCTAssertTrue($0) }
        XCTAssertTrue(invalidated.isEmpty)
        let replacement = NSObject()
        callbacks[1](replacement, true)
        XCTAssertEqual(invalidated, [ObjectIdentifier(old)])
        restriction.release()
        XCTAssertEqual(invalidated, [ObjectIdentifier(old), ObjectIdentifier(replacement)])
    }
}
