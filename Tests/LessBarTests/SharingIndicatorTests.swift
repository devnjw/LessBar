import XCTest
@testable import LessBar

final class SharingIndicatorTests: XCTestCase {
    func testInsetAccessibilityFrameIdentifiesExactlyOneSystemWindow() {
        let frame = CGRect(x: 2110, y: 3, width: 40, height: 24)
        let indicator = SharingIndicator(pid: 10, windowID: 1,
            frame: CGRect(x: 2106, y: 0, width: 48, height: 30))
        let neighbor = SharingIndicator(pid: 10, windowID: 2,
            frame: CGRect(x: 2154, y: 0, width: 30, height: 30))
        XCTAssertEqual(SharingIndicator.matchingWindow(accessibilityFrame: frame,
            windows: [neighbor, indicator]), indicator)
        XCTAssertNil(SharingIndicator.matchingWindow(accessibilityFrame: frame,
            windows: [neighbor]))
        XCTAssertNil(SharingIndicator.matchingWindow(accessibilityFrame: frame,
            windows: [indicator, indicator]))
    }

    func testUnknownOrOversizedWindowCannotBecomeDragTarget() {
        let broad = SharingIndicator(pid: 10, windowID: 1,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 30))
        XCTAssertNil(SharingIndicator.matchingWindow(accessibilityFrame: .zero, windows: [broad]))
        XCTAssertNil(SharingIndicator.matchingWindow(accessibilityFrame:
            CGRect(x: 2110, y: 3, width: 40, height: 24), windows: [broad]))
    }

    func testOnlyIndicatorLeftOfBoundaryNeedsMoving() {
        let area = CGRect(x: 1280, y: 0, width: 1280, height: 30)
        let boundary = CGRect(x: 2106, y: 0, width: 24, height: 30)
        let left = CGRect(x: 1800, y: 0, width: 48, height: 30)
        XCTAssertEqual(SharingIndicatorPlacement.destination(indicator: left,
            boundary: boundary, available: area), CGPoint(x: 2131, y: 15))
        let right = CGRect(x: 2134, y: 0, width: 48, height: 30)
        XCTAssertNil(SharingIndicatorPlacement.destination(indicator: right,
            boundary: boundary, available: area))
        XCTAssertTrue(SharingIndicatorPlacement.isToRight(indicator: right, boundary: boundary))
        XCTAssertFalse(SharingIndicatorPlacement.isToRight(indicator: left, boundary: boundary))
    }

    func testNotchAndDifferentDisplayNeverProduceDrag() {
        let area = CGRect(x: 900, y: 0, width: 900, height: 33)
        let boundary = CGRect(x: 1200, y: 0, width: 24, height: 33)
        for frame in [CGRect(x: 840, y: 0, width: 48, height: 33),
                      CGRect(x: 1000, y: 600, width: 48, height: 33),
                      CGRect.zero] {
            XCTAssertNil(SharingIndicatorPlacement.destination(indicator: frame,
                boundary: boundary, available: area))
        }
    }

    func testOverlappingAndHiddenBoundaryAreRejected() {
        let area = CGRect(x: 0, y: 0, width: 1800, height: 33)
        let indicator = CGRect(x: 1190, y: 0, width: 48, height: 33)
        XCTAssertNil(SharingIndicatorPlacement.destination(indicator: indicator,
            boundary: CGRect(x: 1200, y: 0, width: 24, height: 33), available: area))
        XCTAssertNil(SharingIndicatorPlacement.destination(indicator: indicator,
            boundary: CGRect(x: -2400, y: 0, width: 3600, height: 33), available: area))
    }

    func testNegativeDisplayCoordinatesAndShiftedBoundaryAfterReorder() {
        let area = CGRect(x: -1000, y: 443, width: 1000, height: 33)
        let before = CGRect(x: -430, y: 443, width: 24, height: 33)
        XCTAssertNotNil(SharingIndicatorPlacement.destination(indicator:
            CGRect(x: -800, y: 443, width: 48, height: 33), boundary: before, available: area))
        let after = before.offsetBy(dx: -48, dy: 0)
        XCTAssertTrue(SharingIndicatorPlacement.isToRight(indicator:
            CGRect(x: after.maxX + 4, y: 443, width: 48, height: 33), boundary: after))
    }
}
