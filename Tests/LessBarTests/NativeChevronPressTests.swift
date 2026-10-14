import AppKit
import XCTest
@testable import LessBar

final class NativeChevronPressTests: XCTestCase {
    @MainActor func testOrdinaryClickIsConsumedBeforeNativeTrackingAndFiresOnlyOnce() throws {
        _ = NSApplication.shared
        let item = NSStatusBar.system.statusItem(withLength: 24)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let window = try XCTUnwrap(item.button?.window)
        var presses = 0
        let down = try event(.leftMouseDown, window: window)
        XCTAssertTrue(NativeChevronPress.consume(down) { presses += 1 })
        XCTAssertFalse(NativeChevronPress.consume(try event(.leftMouseUp, window: window)) { presses += 1 })
        XCTAssertEqual(presses, 1)
        XCTAssertFalse(try XCTUnwrap(item.button).isHighlighted)
    }

    @MainActor func testCommandDragContextMenuAndDisabledBoundariesKeepNativeHandling() throws {
        _ = NSApplication.shared
        let item = NSStatusBar.system.statusItem(withLength: 24)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let window = try XCTUnwrap(button.window)
        var presses = 0
        for event in [try event(.leftMouseDown, window: window, modifiers: .command),
                      try event(.leftMouseDragged, window: window, modifiers: .command),
                      try event(.rightMouseDown, window: window),
                      try event(.rightMouseUp, window: window)] {
            XCTAssertFalse(NativeChevronPress.consume(event) { presses += 1 })
        }
        button.isEnabled = false
        XCTAssertFalse(NativeChevronPress.consume(try event(.leftMouseDown, window: window)) { presses += 1 })
        button.isEnabled = true
        window.level = .normal
        XCTAssertFalse(NativeChevronPress.consume(try event(.leftMouseDown, window: window)) { presses += 1 })
        XCTAssertEqual(presses, 0)
    }

    @MainActor private func event(_ type: NSEvent.EventType, window: NSWindow,
        modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero,
            modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
}
