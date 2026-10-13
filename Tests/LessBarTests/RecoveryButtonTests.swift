import AppKit
import XCTest
@testable import LessBar

final class RecoveryButtonTests: XCTestCase {
    @MainActor func testRecoveryPanelReceivesClicksAcrossItsFullRectangle() throws {
        _ = NSApplication.shared
        let recovery = RecoveryController()
        defer { recovery.stop() }
        let anchors = NSScreen.screens.map { screen in
            DisplayAnchor(displayID: MenuBarGeometry.displayID(screen),
                control: CGRect(x: screen.frame.midX, y: screen.frame.midY, width: 24, height: 33),
                available: screen.frame)
        }
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        let button = try XCTUnwrap(recovery.recoveryButton)
        let panel = try XCTUnwrap(button.window)
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        for point in [CGPoint(x: 1, y: 1), CGPoint(x: 23, y: 1),
                      CGPoint(x: 1, y: 32), CGPoint(x: 23, y: 32),
                      CGPoint(x: 12, y: 16)] {
            XCTAssertTrue(button.hitTest(point) === button, "View hit test at \(point)")
            let screenPoint = panel.convertPoint(toScreen: point)
            XCTAssertEqual(NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0),
                panel.windowNumber, "Window Server hit test at \(point)")
        }
        // Leave room for native window-edge rounding on scaled displays.
        for point in [CGPoint(x: -4, y: 16), CGPoint(x: 28, y: 16),
                      CGPoint(x: 12, y: -4), CGPoint(x: 12, y: 37)] {
            let screenPoint = panel.convertPoint(toScreen: point)
            XCTAssertNotEqual(NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0),
                panel.windowNumber, "Clicks outside the control must pass through at \(point)")
        }
    }

    @MainActor func testFirstMouseIsAcceptedWithoutActivation() {
        let button = RecoveryButton()
        XCTAssertTrue(button.acceptsFirstMouse(for: nil))
        XCTAssertFalse(button.acceptsFirstResponder)
    }

    @MainActor func testOneMouseDownRevealsAndMouseUpDoesNotFireAgain() throws {
        let button = RecoveryButton()
        var reveals = 0
        button.onReveal = { reveals += 1 }
        let down = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown,
            location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        let up = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp,
            location: .zero, modifierFlags: [], timestamp: 0.1, windowNumber: 0,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        button.mouseDown(with: down)
        XCTAssertEqual(reveals, 1)
        button.mouseUp(with: up)
        XCTAssertEqual(reveals, 1)
    }

    @MainActor func testRightClickOnlyOpensContextMenu() throws {
        let button = RecoveryButton()
        var reveals = 0
        var menus = 0
        button.onReveal = { reveals += 1 }
        button.onContextMenu = { menus += 1 }
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown,
            location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        button.rightMouseDown(with: event)
        XCTAssertEqual(menus, 1)
        XCTAssertEqual(reveals, 0)
    }
}
