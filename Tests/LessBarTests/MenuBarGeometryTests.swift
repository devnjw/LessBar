import AppKit
import XCTest
@testable import LessBar

final class MenuBarGeometryTests: XCTestCase {
    @MainActor func testUnsupportedOSNeverHidesLegacySecondarySection() {
        _ = NSApplication.shared
        let item = NSStatusBar.system.statusItem(withLength: 24)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let engine = LengthMenuBarEngine(toggle: item, osMajorVersion: 27)
        defer { engine.stop() }
        engine.configure(showDividers: true, alwaysHiddenEnabled: true, editing: false)
        engine.reveal(all: false)
        XCTAssertFalse(engine.alwaysCollapsed)
        engine.hideAlwaysHidden()
        XCTAssertFalse(engine.alwaysCollapsed)
        XCTAssertFalse(engine.setCollapsed(true))
        XCTAssertTrue(engine.isAllExpanded)
    }

    func testRecoveryPreservesNativeChevronCenterAndBaselineOnEachDisplay() throws {
        let screens: [(UInt32, CGRect, CGRect?)] = [
            (1, CGRect(x: 0, y: 0, width: 1728, height: 1117),
                CGRect(x: 956, y: 1085, width: 772, height: 32)),
            (2, CGRect(x: -1920, y: 0, width: 1920, height: 1080), nil)
        ]
        let items = [
            StatusItemGeometry(windowFrame: CGRect(x: 1282, y: 1084, width: 40, height: 33),
                imageFrame: CGRect(x: 1294, y: 1093.5, width: 16, height: 16)),
            StatusItemGeometry(windowFrame: CGRect(x: -400, y: 1055, width: 40, height: 25),
                imageFrame: CGRect(x: -388, y: 1060.5, width: 16, height: 16))
        ]
        let anchors = MenuBarGeometry.recoveryAnchors(items: items, screens: screens)
        XCTAssertEqual(anchors.count, 2)
        for (anchor, item) in zip(anchors, items) {
            let nativeImage = try XCTUnwrap(item.imageFrame)
            XCTAssertEqual(anchor.control.midX, nativeImage.midX)
            XCTAssertEqual(anchor.imageFrame, nativeImage)
            XCTAssertTrue(anchor.control.contains(nativeImage))
            XCTAssertEqual(anchor.control.height, item.windowFrame.height)
        }
        // A 40pt native window has 8pt padding on each side of its 24pt button.
        XCTAssertEqual(anchors.first?.control.minX, 1290)
    }

    func testRecoveryAnchorsIncludeBothDisplaysForOversizedNativeItems() {
        let screens: [(UInt32, CGRect, CGRect?)] = [
            (1, CGRect(x: 0, y: 0, width: 1920, height: 1080), nil),
            (2, CGRect(x: 1920, y: 0, width: 1920, height: 1080), nil)
        ]
        let native = [CGRect(x: -2360, y: 1050, width: 3840, height: 30),
                      CGRect(x: -440, y: 1050, width: 3840, height: 30)]
        let anchors = MenuBarGeometry.recoveryAnchors(items: native.map { StatusItemGeometry(windowFrame: $0) }, screens: screens)
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
            items: [StatusItemGeometry(windowFrame: boundary)], screens: [(1, screen, rightArea)])
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
            items: [StatusItemGeometry(windowFrame: CGRect(x: 956, y: 1084, width: 1, height: 33))],
            screens: [(1, screen, rightArea)])
        XCTAssertTrue(anchors.isEmpty)
    }

    func testVerticalNegativeAndNotchedDisplaysUseTheirOwnTopAndSafeArea() {
        let upper = CGRect(x: -1440, y: 1080, width: 1440, height: 900)
        let area = CGRect(x: -680, y: 1950, width: 680, height: 30)
        let anchors = MenuBarGeometry.recoveryAnchors(
            items: [StatusItemGeometry(windowFrame: CGRect(x: -480, y: 1950, width: 24, height: 30))],
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

    @MainActor func testHoverBoundaryReturnsForEditingAndMissingPermission() throws {
        _ = NSApplication.shared
        let suite = "LessBarTests.geometry.hover.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.showOnHover = true
        preferences.showChevron = false
        let item = NSStatusBar.system.statusItem(withLength: 24)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let engine = LengthMenuBarEngine(toggle: item)
        let window = try XCTUnwrap(item.button?.window)
        engine.configure(showDividers: preferences.showsChevron(accessibilityGranted: true),
            alwaysHiddenEnabled: false, editing: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        engine.synchronizeMirrorSpacing()
        XCTAssertLessThanOrEqual(window.frame.width, 1)
        engine.configure(showDividers: preferences.showsChevron(accessibilityGranted: true),
            alwaysHiddenEnabled: false, editing: true)
        XCTAssertGreaterThan(window.frame.width, 1)
        engine.configure(showDividers: preferences.showsChevron(accessibilityGranted: true),
            alwaysHiddenEnabled: false, editing: false)
        XCTAssertLessThanOrEqual(window.frame.width, 1)
        engine.configure(showDividers: preferences.showsChevron(accessibilityGranted: false),
            alwaysHiddenEnabled: false, editing: false)
        XCTAssertGreaterThan(window.frame.width, 1)
        XCTAssertTrue(item.isVisible) // The boundary retains its saved position.
    }
}
