import AppKit
import XCTest
@testable import LessBar

final class RecoveryButtonTests: XCTestCase {
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
