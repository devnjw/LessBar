import AppKit
import XCTest
@testable import LessBar

final class RecoveryHandoffTests: XCTestCase {
    @MainActor func testReplacementIsVisibleBeforeNativeChevronDisappears() throws {
        _ = NSApplication.shared
        let recovery = RecoveryController(occupiedFrames: { [] })
        defer { recovery.stop() }
        let anchors = anchors()
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        let button = try XCTUnwrap(recovery.recoveryButton)
        var collapsed = false
        XCTAssertTrue(recovery.handoffToCollapsed {
            // No run loop or retry timer has fired: every replacement is ready
            // while the old native chevron is still present.
            XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
            XCTAssertTrue(button.image === ChevronAppearance.image(collapsed: false))
            collapsed = true
            return true
        })
        XCTAssertTrue(collapsed)
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
        XCTAssertTrue(button.image === ChevronAppearance.image(collapsed: true))
        XCTAssertEqual(button.window?.animationBehavior, NSWindow.AnimationBehavior.none)
    }

    @MainActor func testUnknownOrUnsafePlacementNeverHidesTheNativeChevron() {
        _ = NSApplication.shared
        let anchors = anchors()
        for occupied: [CGRect]? in [nil, anchors.map(\.available)] {
            let recovery = RecoveryController(occupiedFrames: { occupied })
            defer { recovery.stop() }
            XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
            var collapsed = false
            XCTAssertFalse(recovery.handoffToCollapsed { collapsed = true; return true })
            XCTAssertFalse(collapsed)
            XCTAssertTrue(recovery.visibleFrames.isEmpty)
        }
    }

    @MainActor func testProtectedItemIsNotCoveredDuringHandoff() {
        _ = NSApplication.shared
        let anchors = anchors()
        let occupied = anchors.map(\.control)
        let recovery = RecoveryController(occupiedFrames: { occupied })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        XCTAssertTrue(recovery.handoffToCollapsed {
            XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
            XCTAssertTrue(recovery.visibleFrames.allSatisfy { frame in
                !occupied.contains { frame.intersects($0) }
            })
            return true
        })
    }

    @MainActor func testRejectedCollapseRemovesStagedPanels() {
        _ = NSApplication.shared
        let recovery = RecoveryController(occupiedFrames: { [] })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors(), showControls: true))
        XCTAssertFalse(recovery.handoffToCollapsed { false })
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        XCTAssertNil(recovery.recoveryButton)
    }

    @MainActor func testInvisibleDividersDoNotShowAPanelOrRequirePlacement() {
        _ = NSApplication.shared
        let recovery = RecoveryController(occupiedFrames: { nil })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors(), showControls: false))
        var collapsed = false
        XCTAssertTrue(recovery.handoffToCollapsed { collapsed = true; return true })
        XCTAssertTrue(collapsed)
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
    }

    @MainActor private func anchors() -> [DisplayAnchor] {
        NSScreen.screens.map { screen in
            DisplayAnchor(displayID: MenuBarGeometry.displayID(screen),
                control: CGRect(x: screen.frame.midX, y: screen.frame.midY, width: 24, height: 33),
                available: screen.frame)
        }
    }
}
