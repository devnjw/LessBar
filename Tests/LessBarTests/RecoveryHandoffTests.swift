import AppKit
import XCTest
@testable import LessBar

final class RecoveryHandoffTests: XCTestCase {
    @MainActor func testReplacementIsVisibleBeforeNativeChevronDisappears() throws {
        _ = NSApplication.shared
        let recovery = recovery(occupiedFrames: { [] })
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
            let recovery = recovery(occupiedFrames: { occupied })
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
        let recovery = recovery(occupiedFrames: { occupied })
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
        let recovery = recovery(occupiedFrames: { [] })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors(), showControls: true))
        XCTAssertFalse(recovery.handoffToCollapsed { false })
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        XCTAssertNil(recovery.recoveryButton)
    }

    @MainActor func testInvisibleDividersDoNotShowAPanelOrRequirePlacement() {
        _ = NSApplication.shared
        let recovery = recovery(occupiedFrames: { nil })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors(), showControls: false))
        var collapsed = false
        XCTAssertTrue(recovery.handoffToCollapsed { collapsed = true; return true })
        XCTAssertTrue(collapsed)
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
    }

    @MainActor func testHoverPanelsStayHiddenAndReturnForPermissionFallback() {
        _ = NSApplication.shared
        let recovery = recovery(occupiedFrames: { [] })
        defer { recovery.stop() }
        let anchors = anchors()
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: false))
        XCTAssertTrue(recovery.handoffToCollapsed { true })
        recovery.startMonitoring()
        recovery.refreshVisibility()
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        XCTAssertEqual(Set(recovery.displayIDs), Set(anchors.map(\.displayID)))
        // Reconfiguration after losing permission must restore every display's
        // control, rather than retaining an invisible collapsed recovery session.
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        recovery.startMonitoring()
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
    }

    @MainActor func testHiddenMenuBarKeepsCollapseAndReturnsWhenShown() throws {
        _ = NSApplication.shared
        let anchors = anchors()
        let allDisplays = Set(anchors.map(\.displayID))
        var visibleDisplays = allDisplays
        var occupied: [CGRect]? = []
        let recovery = RecoveryController(occupiedFrames: { occupied },
            visibleMenuBarDisplays: { visibleDisplays })
        defer { recovery.stop() }
        var reveals = 0
        recovery.onReveal = { reveals += 1 }
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        XCTAssertTrue(recovery.handoffToCollapsed { true })
        recovery.startMonitoring()
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count)

        // A display entering full screen does not affect the other menu bars.
        let hidden = try XCTUnwrap(anchors.first)
        visibleDisplays.remove(hidden.displayID)
        recovery.refreshVisibility()
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count - 1)
        XCTAssertFalse(recovery.visibleFrames.contains(hidden.control))

        // Hidden menu bars are not a failure, even beyond the recovery deadline.
        visibleDisplays = []
        occupied = nil
        recovery.refreshVisibility()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        XCTAssertEqual(reveals, 0)
        XCTAssertEqual(Set(recovery.displayIDs), allDisplays)

        occupied = []
        visibleDisplays = allDisplays
        recovery.refreshVisibility()
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
        XCTAssertEqual(reveals, 0)
        XCTAssertTrue(recovery.recoveryButton?.image === ChevronAppearance.image(collapsed: true))
    }

    @MainActor func testCollapseWhileMenuBarHiddenDoesNotStageAnOverlay() {
        _ = NSApplication.shared
        var visibleDisplays: Set<UInt32> = []
        let anchors = anchors()
        let recovery = RecoveryController(occupiedFrames: { visibleDisplays.isEmpty ? nil : [] },
            visibleMenuBarDisplays: { visibleDisplays })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        XCTAssertTrue(recovery.handoffToCollapsed {
            XCTAssertTrue(recovery.visibleFrames.isEmpty)
            return true
        })
        recovery.startMonitoring()
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        visibleDisplays = Set(anchors.map(\.displayID))
        recovery.refreshVisibility()
        XCTAssertEqual(recovery.visibleFrames.count, anchors.count)
    }

    @MainActor func testReturningMenuBarStillChecksProtectedItemsAndStopCancelsPolling() {
        _ = NSApplication.shared
        let anchors = anchors()
        var visibleDisplays: Set<UInt32> = []
        let recovery = RecoveryController(occupiedFrames: { anchors.map(\.available) },
            visibleMenuBarDisplays: { visibleDisplays })
        defer { recovery.stop() }
        XCTAssertTrue(recovery.prepare(anchors: anchors, showControls: true))
        XCTAssertTrue(recovery.handoffToCollapsed { true })
        recovery.startMonitoring()
        visibleDisplays = Set(anchors.map(\.displayID))
        recovery.refreshVisibility()
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        recovery.stop()
        recovery.refreshVisibility()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        XCTAssertTrue(recovery.visibleFrames.isEmpty)
        XCTAssertTrue(recovery.displayIDs.isEmpty)
    }

    @MainActor private func recovery(occupiedFrames: @escaping () -> [CGRect]?) -> RecoveryController {
        RecoveryController(occupiedFrames: occupiedFrames,
            visibleMenuBarDisplays: { Set(NSScreen.screens.map(MenuBarGeometry.displayID)) })
    }

    @MainActor private func anchors() -> [DisplayAnchor] {
        NSScreen.screens.map { screen in
            DisplayAnchor(displayID: MenuBarGeometry.displayID(screen),
                control: CGRect(x: screen.frame.midX, y: screen.frame.midY, width: 24, height: 33),
                available: screen.frame)
        }
    }
}
