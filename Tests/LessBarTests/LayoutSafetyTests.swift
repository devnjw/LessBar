import XCTest
@testable import LessBar

final class LayoutSafetyTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testCollapseKeepsControlAtSamePosition() {
        let expanded = CGRect(x: 1200, y: 876, width: 24, height: 24)
        let collapsed = CGRect(x: -1656, y: 876, width: 2880, height: 24)
        XCTAssertEqual(LayoutSafety.controlRect(in: expanded), LayoutSafety.controlRect(in: collapsed))
        XCTAssertTrue(LayoutSafety.isControlVisible(item: collapsed, screen: screen))
    }

    func testOffscreenControlTriggersRecovery() {
        XCTAssertFalse(LayoutSafety.isControlVisible(
            item: CGRect(x: -3000, y: 876, width: 2880, height: 24), screen: screen))
        XCTAssertFalse(LayoutSafety.isControlVisible(
            item: CGRect(x: 1430, y: 876, width: 24, height: 24), screen: screen))
    }

    func testUnknownOrInvalidLayoutBlocksCollapse() {
        XCTAssertFalse(LayoutSafety.isControlVisible(item: nil, screen: screen))
        XCTAssertFalse(LayoutSafety.isControlVisible(item: .zero, screen: screen))
    }

    func testSecondaryDisplayWithNegativeOrigin() {
        XCTAssertTrue(LayoutSafety.isControlVisible(
            item: CGRect(x: -3100, y: 876, width: 2880, height: 24),
            screen: CGRect(x: -1440, y: 0, width: 1440, height: 900)))
    }

    func testSharingIndicatorMovesRecoveryToItsLeft() throws {
        // Captured geometry: the 48pt sharing indicator reflows over the old
        // 24pt control after AppKit removes the oversized native item.
        let anchor = CGRect(x: 1355, y: 1087, width: 24, height: 28)
        let sharing = CGRect(x: 1339, y: 1084, width: 48, height: 33)
        let area = CGRect(x: 864, y: 0, width: 864, height: 1117)
        let result = try XCTUnwrap(LayoutSafety.recoveryFrame(anchor: anchor, available: area,
                                                              occupied: [sharing]))
        XCTAssertEqual(result, CGRect(x: 1313, y: 1087, width: 24, height: 28))
        XCTAssertFalse(result.intersects(sharing))
        // Repeated checks must not walk the button farther to the left.
        XCTAssertEqual(LayoutSafety.recoveryFrame(anchor: anchor, available: area,
                                                  occupied: [sharing]), result)
        // Once sharing stops, return to the user's original boundary.
        XCTAssertEqual(LayoutSafety.recoveryFrame(anchor: anchor, available: area, occupied: []), anchor)
    }

    func testRelocationAvoidsNeighboringStatusItemsToo() throws {
        let anchor = CGRect(x: 1200, y: 876, width: 24, height: 24)
        let obstacles = [CGRect(x: 1190, y: 872, width: 50, height: 28),
                         CGRect(x: 1150, y: 872, width: 40, height: 28)]
        let result = try XCTUnwrap(LayoutSafety.recoveryFrame(anchor: anchor, available: screen,
                                                              occupied: obstacles))
        XCTAssertEqual(result.minX, 1124)
        XCTAssertTrue(obstacles.allSatisfy { !result.intersects($0) })
    }

    func testNoSafeRoomFallsBackToExpandedInsteadOfCoveringNotch() {
        let anchor = CGRect(x: 820, y: 876, width: 24, height: 24)
        let rightOfNotch = CGRect(x: 800, y: 872, width: 640, height: 28)
        XCTAssertNil(LayoutSafety.recoveryFrame(anchor: anchor, available: rightOfNotch,
            occupied: [CGRect(x: 810, y: 872, width: 80, height: 28)]))
        XCTAssertNil(LayoutSafety.recoveryFrame(anchor: anchor, available: screen,
            occupied: [CGRect(x: 500, y: 872, width: 400, height: 28)]))
    }

    func testWindowsBelowMenuAndOnOtherDisplayDoNotMoveControl() {
        let anchor = CGRect(x: 1200, y: 876, width: 24, height: 24)
        XCTAssertEqual(LayoutSafety.recoveryFrame(anchor: anchor, available: screen,
            occupied: [CGRect(x: 1190, y: 500, width: 100, height: 100),
                       CGRect(x: -300, y: 876, width: 80, height: 24)]), anchor)
    }

    func testWindowServerConversionForMainAndUpperSecondaryScreen() {
        XCTAssertEqual(LayoutSafety.appKitFrame(
            fromWindowServer: CGRect(x: 1339, y: 0, width: 48, height: 33), primaryScreenMaxY: 1117),
            CGRect(x: 1339, y: 1084, width: 48, height: 33))
        XCTAssertEqual(LayoutSafety.appKitFrame(
            fromWindowServer: CGRect(x: -1440, y: -900, width: 48, height: 24), primaryScreenMaxY: 1117),
            CGRect(x: -1440, y: 1993, width: 48, height: 24))
    }
}
