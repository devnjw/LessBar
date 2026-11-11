import XCTest
@testable import LessBar

final class NativeMenuBarVisibilityTests: XCTestCase {
    private let boundary = CGRect(x: 400, y: 0, width: 24, height: 30)
    private func item(_ bundle: String, _ x: CGFloat) -> NativeMenuBarItem {
        .init(bundle: bundle, frame: CGRect(x: x, y: 0, width: 20, height: 30))
    }

    func testHiddenIconAreaIsEmptyButVisibleAndSystemIconsRemainOccupied() {
        let items = [item("hidden.app", 200), item("visible.app", 500),
                     item("com.apple.MenuBarAgent", 600)]
        let occupied = NativeMenuBarSelection.occupiedFrames(items: items,
            allowedBundles: ["visible.app", "com.apple.MenuBarAgent"])
        let menu = CGRect(x: 0, y: 0, width: 1000, height: 30)
        let menus = [CGRect(x: 0, y: 0, width: 100, height: 30)]
        // Both hover and empty-space click use this same hit test.
        XCTAssertTrue(MenuBarGeometry.isEmpty(point: CGPoint(x: 210, y: 15),
            menu: menu, applicationMenus: menus, statusItems: occupied))
        for x in [CGFloat(510), 610, 50] {
            XCTAssertFalse(MenuBarGeometry.isEmpty(point: CGPoint(x: x, y: 15),
                menu: menu, applicationMenus: menus, statusItems: occupied))
        }
        let revealed = NativeMenuBarSelection.occupiedFrames(items: items, allowedBundles: nil)
        XCTAssertFalse(MenuBarGeometry.isEmpty(point: CGPoint(x: 210, y: 15),
            menu: menu, applicationMenus: menus, statusItems: revealed))
    }

    func testVisibilityFilterHandlesSharedIconsAndNewAppsWhileCollapsed() {
        let items = [item("mixed", 200), item("mixed", 500), item("new.hidden", 300)]
        XCTAssertEqual(NativeMenuBarSelection.occupiedFrames(items: items,
            allowedBundles: ["mixed"]).count, 2)
        XCTAssertEqual(NativeMenuBarSelection.occupiedFrames(items: items,
            allowedBundles: nil).count, 3)
    }

    func testLeftSideHidesWhileVisibleAndSystemAppsStayAllowed() {
        let allowed = NativeMenuBarSelection.allowed(items: [item("hidden", 200), item("visible", 500)],
            boundary: boundary, ownBundle: "lessbar", leftToRight: true)
        XCTAssertFalse(allowed.contains("hidden"))
        XCTAssertTrue(allowed.contains("visible"))
        XCTAssertTrue(allowed.contains("lessbar"))
        XCTAssertTrue(allowed.contains("com.apple.controlcenter"))
        XCTAssertTrue(allowed.contains("com.apple.systemuiserver"))
    }

    func testMixedPlacementOfOneAppsIconsKeepsAllItsIconsVisible() {
        let allowed = NativeMenuBarSelection.allowed(items: [item("mixed", 200), item("mixed", 500)],
            boundary: boundary, ownBundle: "lessbar", leftToRight: true)
        XCTAssertEqual(allowed.filter { $0 == "mixed" }.count, 1)
    }

    func testSystemOwnerOnTheHiddenSideStaysAllowed() {
        let allowed = NativeMenuBarSelection.allowed(items: [item("com.apple.MenuBarAgent", 200),
            item("com.apple.TextInputMenuAgent", 250), item("third.party", 300)],
            boundary: boundary, ownBundle: "lessbar", leftToRight: true)
        XCTAssertTrue(allowed.contains("com.apple.MenuBarAgent"))
        XCTAssertTrue(allowed.contains("com.apple.TextInputMenuAgent"))
        XCTAssertFalse(allowed.contains("third.party"))
    }

    func testRightToLeftReversesTheHiddenSide() {
        let allowed = NativeMenuBarSelection.allowed(items: [item("visible", 200), item("hidden", 500)],
            boundary: boundary, ownBundle: "lessbar", leftToRight: false)
        XCTAssertTrue(allowed.contains("visible"))
        XCTAssertFalse(allowed.contains("hidden"))
    }
}
