import XCTest
@testable import LessBar

final class LayoutRecoveryTests: XCTestCase {
    func testStaleExpandedGeometryThenSharingLayoutKeepsCollapsed() {
        let anchor = CGRect(x: 1355, y: 1087, width: 24, height: 28)
        let area = CGRect(x: 864, y: 0, width: 864, height: 1117)
        // Before Window Server catches up, ordinary icons still form an
        // occupied run wider than the permitted recovery-button movement.
        let expanded = stride(from: 1075.0, through: 1355.0, by: 40).map {
            CGRect(x: $0 - 8, y: 1084, width: 40, height: 33)
        }
        let staleFrame = LayoutSafety.recoveryFrame(anchor: anchor, available: area,
                                                    occupied: expanded)
        XCTAssertNil(staleFrame)
        var recovery = LayoutRecovery(now: 0)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: staleFrame != nil, now: 0.075), .retry)
        let sharing = CGRect(x: 1339, y: 1084, width: 48, height: 33)
        let settledFrame = LayoutSafety.recoveryFrame(anchor: anchor, available: area,
                                                      occupied: [sharing])
        XCTAssertNotNil(settledFrame)
        XCTAssertFalse(settledFrame!.intersects(sharing))
        XCTAssertEqual(recovery.evaluate(controlIsSafe: settledFrame != nil, now: 0.15), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: settledFrame != nil, now: 0.8), .monitor)
    }

    func testWatchdogBeforeFirstPresentationDoesNotUndoCollapse() {
        var recovery = LayoutRecovery(now: 100)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 100.001), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 100.5), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 100.6), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 100.8), .monitor)
    }

    func testTransientSharingReflowDoesNotReveal() {
        var recovery = LayoutRecovery(now: 0)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 1), .monitor)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 50), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 50.5), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 50.6), .monitor)
        // A later, unrelated transition gets its own recovery window.
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 80), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 80.1), .monitor)
    }

    func testPermanentFailureStillRevealsWithinBoundedTime() {
        var recovery = LayoutRecovery(now: 10)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 10.5), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 10.75), .reveal)
    }

    func testRepeatedWatchdogChecksDoNotExtendFailureDeadline() {
        var recovery = LayoutRecovery(now: 0)
        _ = recovery.evaluate(controlIsSafe: true, now: 1)
        for time in stride(from: 20.0, through: 20.7, by: 0.05) {
            XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: time), .retry)
        }
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 20.75), .reveal)
    }

    func testNewCollapseDoesNotInheritPreviousFailureDeadline() {
        var recovery = LayoutRecovery(now: 0)
        _ = recovery.evaluate(controlIsSafe: false, now: 0.7)
        recovery = LayoutRecovery(now: 0.72)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 0.8), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 0.9), .retry)
    }

    func testEarlySafeSnapshotStillChecksForFollowingReflow() {
        var recovery = LayoutRecovery(now: 0)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 0.075), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: false, now: 0.15), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 0.225), .retry)
        XCTAssertEqual(recovery.evaluate(controlIsSafe: true, now: 0.8), .monitor)
    }
}
