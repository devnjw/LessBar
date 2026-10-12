import AppKit
import XCTest
@testable import LessBar

final class MenuBarGeometryTests: XCTestCase {
    func testRecoveryAnchorsIncludeBothDisplaysForOversizedNativeItems() {
        let screens: [(UInt32, CGRect, CGRect?)] = [
            (1, CGRect(x: 0, y: 0, width: 1920, height: 1080), nil),
            (2, CGRect(x: 1920, y: 0, width: 1920, height: 1080), nil)
        ]
        let native = [CGRect(x: -2360, y: 1050, width: 3840, height: 30),
                      CGRect(x: -440, y: 1050, width: 3840, height: 30)]
        let anchors = MenuBarGeometry.recoveryAnchors(windows: native, screens: screens)
        XCTAssertEqual(anchors.map(\.displayID), [1, 2])
        XCTAssertEqual(anchors.map { $0.control.maxX }, [1480, 3400])
    }

    func testNotchedLaptopAnchorUsesNativeMenuBarHeight() {
        // Captured on the built-in display after disconnecting external displays:
        // native status windows are 33pt high, while the notch safe area is 32pt.
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let rightArea = CGRect(x: 956, y: 1085, width: 772, height: 32)
        let boundary = CGRect(x: 1301, y: 1084, width: 1, height: 33)
        let anchors = MenuBarGeometry.recoveryAnchors(
            windows: [boundary], screens: [(1, screen, rightArea)])
        XCTAssertEqual(anchors.map(\.displayID), [1])
        let anchor = anchors.first
        XCTAssertEqual(anchor?.control.height, 33)
        XCTAssertEqual(anchor?.available.minX, rightArea.minX)
        XCTAssertEqual(anchor?.available.maxX, rightArea.maxX)
        XCTAssertEqual(anchor?.available.minY, boundary.minY)
        XCTAssertEqual(anchor?.available.maxY, boundary.maxY)
        XCTAssertEqual(anchor.map { $0.available.contains($0.control) }, true)
    }

    func testNotchedLaptopAnchorCannotCrossHorizontalSafeArea() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let rightArea = CGRect(x: 956, y: 1085, width: 772, height: 32)
        let anchors = MenuBarGeometry.recoveryAnchors(
            windows: [CGRect(x: 956, y: 1084, width: 1, height: 33)],
            screens: [(1, screen, rightArea)])
        XCTAssertTrue(anchors.isEmpty)
    }

    func testVerticalNegativeAndNotchedDisplaysUseTheirOwnTopAndSafeArea() {
        let upper = CGRect(x: -1440, y: 1080, width: 1440, height: 900)
        let area = CGRect(x: -680, y: 1950, width: 680, height: 30)
        let anchors = MenuBarGeometry.recoveryAnchors(
            windows: [CGRect(x: -480, y: 1950, width: 24, height: 30)],
            screens: [(3, upper, area)])
        XCTAssertEqual(anchors.first?.displayID, 3)
        XCTAssertEqual(anchors.first?.control.maxY, 1980)
        XCTAssertEqual(anchors.first?.available, area)
    }

    func testUnknownOrOccupiedMenuAreaNeverReveals() {
        let menu = CGRect(x: 1920, y: 1050, width: 1920, height: 30)
        let apps = [CGRect(x: 1920, y: 1050, width: 350, height: 30)]
        let icons = [CGRect(x: 3600, y: 1050, width: 240, height: 30)]
        XCTAssertTrue(MenuBarGeometry.isEmpty(point: CGPoint(x: 2600, y: 1060),
            menu: menu, applicationMenus: apps, statusItems: icons))
        XCTAssertFalse(MenuBarGeometry.isEmpty(point: CGPoint(x: 2000, y: 1060),
            menu: menu, applicationMenus: apps, statusItems: icons))
        XCTAssertFalse(MenuBarGeometry.isEmpty(point: CGPoint(x: 3650, y: 1060),
            menu: menu, applicationMenus: apps, statusItems: icons))
        XCTAssertFalse(MenuBarGeometry.isEmpty(point: CGPoint(x: 2600, y: 1060),
            menu: menu, applicationMenus: nil, statusItems: icons))
    }

    @MainActor func testNativeInvisibleBoundaryHasNoSixteenPointPadding() throws {
        _ = NSApplication.shared
        let item = NSStatusBar.system.statusItem(withLength: 24)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let engine = LengthMenuBarEngine(toggle: item)
        engine.configure(showDividers: false, alwaysHiddenEnabled: false, editing: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        engine.synchronizeMirrorSpacing()
        let window = try XCTUnwrap(item.button?.window)
        XCTAssertLessThanOrEqual(window.frame.width, 1)
        let nativeWindows = NSApp.windows.filter { $0.level.rawValue == Int(CGWindowLevelForKey(.statusWindow)) }
        XCTAssertTrue(nativeWindows.allSatisfy { $0.frame.width <= 1 }, String(describing: nativeWindows.map { $0.frame }))
        engine.configure(showDividers: true, alwaysHiddenEnabled: false, editing: false)
        XCTAssertGreaterThan(window.frame.width, 1)
    }
}
