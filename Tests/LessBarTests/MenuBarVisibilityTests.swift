import AppKit
import XCTest
@testable import LessBar

final class MenuBarVisibilityTests: XCTestCase {
    private let screens: [(UInt32, CGRect)] = [
        (1, CGRect(x: 0, y: 0, width: 2560, height: 1440)),
        (2, CGRect(x: -1728, y: -120, width: 1728, height: 1117))
    ]

    func testVisibilityIsIndependentForOffsetAndNotchedDisplays() {
        let primary = window(CGRect(x: 0, y: 0, width: 2560, height: 30))
        let secondary = window(CGRect(x: -1728, y: 443, width: 1728, height: 33))
        XCTAssertEqual(visible([primary, secondary]), [1, 2])
        XCTAssertEqual(visible([primary]), [1])
        XCTAssertEqual(visible([secondary]), [2])
        XCTAssertTrue(visible([]).isEmpty)
    }

    func testHiddenSlidingOrUnrelatedWindowsCannotKeepChevronVisible() {
        let frame = CGRect(x: 0, y: 0, width: 2560, height: 30)
        XCTAssertTrue(visible([window(frame, alpha: 0)]).isEmpty)
        XCTAssertTrue(visible([window(frame.offsetBy(dx: 0, dy: -15))]).isEmpty)
        XCTAssertTrue(visible([window(frame, level: .statusWindow)]).isEmpty)
        XCTAssertTrue(visible([window(frame, level: .popUpMenuWindow)]).isEmpty)
        XCTAssertTrue(visible([window(CGRect(x: 100, y: 0, width: 600, height: 30))]).isEmpty)
        XCTAssertTrue(visible([window(CGRect(x: 0, y: 0, width: 2560, height: 1440))]).isEmpty)
        XCTAssertTrue(visible([[kCGWindowLayer as String: Int(CGWindowLevelForKey(.mainMenuWindow))]]).isEmpty)
    }

    private func visible(_ windows: [[String: Any]]) -> Set<UInt32> {
        MenuBarVisibility.visibleDisplayIDs(windows: windows, primaryScreenMaxY: 1440, screens: screens)
    }

    private func window(_ bounds: CGRect, alpha: Double = 1,
                        level: CGWindowLevelKey = .mainMenuWindow) -> [String: Any] {
        [kCGWindowLayer as String: Int(CGWindowLevelForKey(level)),
         kCGWindowAlpha as String: alpha, kCGWindowBounds as String: bounds.dictionaryRepresentation]
    }
}
