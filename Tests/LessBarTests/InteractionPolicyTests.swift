import XCTest
@testable import LessBar

final class InteractionPolicyTests: XCTestCase {
    func testHoverRequiresDwellAndOnlyRevealsOnce() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(hoverDelay: 0.2)
        XCTAssertTrue(policy.step(.init(now: 10, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 10.19, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 10.2, menuDisplayID: 1, emptyDisplayID: 1), configuration: config), [.revealNormal])
        XCTAssertTrue(policy.step(.init(now: 11, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
    }

    func testMovingToAnotherMonitorsEmptyAreaRestartsHoverDwell() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(hoverDelay: 0.2)
        _ = policy.step(.init(now: 0, menuDisplayID: 1, emptyDisplayID: 1), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 0.1, menuDisplayID: 2, emptyDisplayID: 2), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 0.29, menuDisplayID: 2, emptyDisplayID: 2), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.3, menuDisplayID: 2, emptyDisplayID: 2), configuration: config), [.revealNormal])
    }

    func testManualCollapseWhilePointerOnMenuBarWaitsForExitAndReentry() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(hoverDelay: 0)
        policy.didCollapse(pointerInMenuBar: true)
        XCTAssertTrue(policy.step(.init(now: 1, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        _ = policy.step(.init(now: 2, menuDisplayID: nil), configuration: config)
        XCTAssertEqual(policy.step(.init(now: 3, menuDisplayID: 1, emptyDisplayID: 1), configuration: config), [.revealNormal])
    }

    func testClickCanRevealImmediatelyAfterManualCollapse() {
        var policy = InteractionPolicy()
        policy.didCollapse(pointerInMenuBar: true)
        XCTAssertEqual(policy.step(.init(now: 1, menuDisplayID: 1, emptyDisplayID: 1, clickOnEmpty: true), configuration: .init()), [.revealNormal])
    }

    func testHoverWaitsUntilBusyInputAndMenuAreClear() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(hoverDelay: 0)
        XCTAssertTrue(policy.step(.init(now: 0, menuDisplayID: 1, emptyDisplayID: 1, mouseDown: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.1, menuDisplayID: 1, emptyDisplayID: 1), configuration: config), [.revealNormal])

        policy.didCollapse(pointerInMenuBar: false)
        XCTAssertEqual(policy.step(.init(now: 1, menuDisplayID: 1, emptyDisplayID: 1, command: true), configuration: config), [.beginEditing])
    }

    func testTurningHoverOffCancelsPendingDwellAndTurningItOnStartsWithoutMovement() {
        var policy = InteractionPolicy()
        var config = InteractionPolicy.Configuration(hoverDelay: 0.2)
        _ = policy.step(.init(now: 0, menuDisplayID: 1, emptyDisplayID: 1), configuration: config)

        config.showOnHover = false
        XCTAssertTrue(policy.step(.init(now: 0.1, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        config.showOnHover = true
        XCTAssertTrue(policy.step(.init(now: 0.2, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.4, menuDisplayID: 1, emptyDisplayID: 1), configuration: config), [.revealNormal])
    }

    func testChangingPendingHoverDelayRestartsDwell() {
        var policy = InteractionPolicy()
        var config = InteractionPolicy.Configuration(hoverDelay: 0.2)
        _ = policy.step(.init(now: 0, menuDisplayID: 1, emptyDisplayID: 1), configuration: config)
        config.hoverDelay = 0.5
        XCTAssertTrue(policy.step(.init(now: 0.19, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 0.68, menuDisplayID: 1, emptyDisplayID: 1), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.69, menuDisplayID: 1, emptyDisplayID: 1), configuration: config), [.revealNormal])
    }

    func testClickRevealsImmediatelyOnlyOnEmptyArea() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration()
        XCTAssertTrue(policy.step(.init(now: 0, menuDisplayID: 1, emptyDisplayID: nil, clickOnEmpty: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 1, menuDisplayID: 1, emptyDisplayID: 1, clickOnEmpty: true), configuration: config), [.revealNormal])
        XCTAssertTrue(policy.step(.init(now: 2, menuDisplayID: 1, emptyDisplayID: 1, clickOnEmpty: true), configuration: config).isEmpty)
    }

    func testAfterExitTimerCancelsOnReentryAndRestartsOnNextExit() {
        var policy = InteractionPolicy()
        var config = InteractionPolicy.Configuration(rehideDelay: 1)
        config.rehideStrategy = .afterExit
        policy.didReveal(now: 0)
        _ = policy.step(.init(now: 0, menuDisplayID: 1), configuration: config)
        _ = policy.step(.init(now: 1, menuDisplayID: nil), configuration: config)
        _ = policy.step(.init(now: 1.5, menuDisplayID: 2), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 2.1, menuDisplayID: 2), configuration: config).isEmpty)
        _ = policy.step(.init(now: 3, menuDisplayID: nil), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 3.9, menuDisplayID: nil), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 4, menuDisplayID: nil), configuration: config), [.collapse])
    }

    func testTimedRehideWaitsWhileBlockedThenCollapsesOnce() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(rehideStrategy: .timed, rehideDelay: 1)
        policy.didReveal(now: 0)
        _ = policy.step(.init(now: 0, menuDisplayID: 1), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 1, menuDisplayID: 1, mouseDown: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 1.1, menuDisplayID: 1), configuration: config), [.collapse])
        XCTAssertTrue(policy.step(.init(now: 2, menuDisplayID: 1), configuration: config).isEmpty)
    }

    func testTemporaryAllTimerDoesNotEndWhileMenuIsTracked() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(temporaryShowDelay: 2)
        policy.didReveal(now: 0, temporaryAll: true, temporaryDelay: config.temporaryShowDelay)
        _ = policy.step(.init(now: 0, menuDisplayID: 1), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 2, menuDisplayID: 1, menuOpen: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 2.1, menuDisplayID: 1), configuration: config), [.endTemporaryAll])
        XCTAssertTrue(policy.step(.init(now: 3, menuDisplayID: 1), configuration: config).isEmpty)
    }

    func testZeroDelayRehidesImmediatelyOnExit() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(rehideDelay: 0)
        policy.didReveal(now: 0)
        XCTAssertTrue(policy.step(.init(now: 0, menuDisplayID: 1), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 1, menuDisplayID: nil), configuration: config), [.collapse])
    }

    func testFractionalExitDelayDoesNotRoundToWholeSeconds() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(rehideDelay: 0.1)
        policy.didReveal(now: 0)
        _ = policy.step(.init(now: 0, menuDisplayID: 1), configuration: config)
        XCTAssertTrue(policy.step(.init(now: 1, menuDisplayID: nil), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 1.099, menuDisplayID: nil), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 1.1, menuDisplayID: nil), configuration: config), [.collapse])
    }

    func testCommandEditingEmitsOneBeginAndEndAndTracksDrag() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(showAllOnCommandDrag: true)
        XCTAssertTrue(policy.step(.init(now: 0, menuDisplayID: nil, command: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.05, menuDisplayID: 1, command: true), configuration: config), [.beginEditing])
        XCTAssertTrue(policy.step(.init(now: 0.1, menuDisplayID: 1, command: true), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 0.2, menuDisplayID: 1, command: true, dragInProgress: true), configuration: config).isEmpty)
        XCTAssertTrue(policy.step(.init(now: 0.3, menuDisplayID: 1, mouseDown: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.4, menuDisplayID: 1), configuration: config), [.endEditing(didDrag: true)])
    }

    func testCommandWithoutDragEndsAfterCommandAndMouseRelease() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(showAllOnCommandDrag: true)
        XCTAssertTrue(policy.step(.init(now: 0, menuDisplayID: nil, command: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.1, menuDisplayID: 1, command: true), configuration: config), [.beginEditing])
        XCTAssertTrue(policy.step(.init(now: 0.2, menuDisplayID: 1, mouseDown: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 0.3, menuDisplayID: 1), configuration: config), [.endEditing(didDrag: false)])
    }

    func testNormalRevealClearsAllVisibleState() {
        var policy = InteractionPolicy()
        policy.didReveal(now: 0, temporaryAll: true, temporaryDelay: 4)
        XCTAssertTrue(policy.allVisible)
        policy.didReveal(now: 1)
        XCTAssertFalse(policy.allVisible)
    }

    func testRevealAllRequestIsEdgeTriggeredAndTemporaryDeadlineIsIndependent() {
        var policy = InteractionPolicy()
        let config = InteractionPolicy.Configuration(temporaryShowDelay: 4)
        XCTAssertEqual(policy.step(.init(now: 0, menuDisplayID: 1, requestRevealAll: true), configuration: config), [.revealAll])
        XCTAssertTrue(policy.step(.init(now: 2, menuDisplayID: 1, requestRevealAll: true), configuration: config).isEmpty)
        XCTAssertEqual(policy.step(.init(now: 4, menuDisplayID: 1), configuration: config), [.endTemporaryAll])
    }
}
