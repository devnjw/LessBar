import AppKit
import SwiftUI
import XCTest
@testable import LessBar

final class SettingsWindowTests: XCTestCase {
    @MainActor func testHeightIsLimitedByAvailableSpaceBelowTheFixedTop() {
        let screen = NSRect(x: 0, y: 40, width: 1024, height: 700)
        XCTAssertEqual(SettingsWindowController.fittingHeight(1000, top: 650, visibleFrame: screen), 610)
        XCTAssertEqual(SettingsWindowController.fittingHeight(300, top: 650, visibleFrame: screen), 300)
        XCTAssertEqual(SettingsWindowController.fittingHeight(1000, top: 900, visibleFrame: screen), 700)
    }

    @MainActor func testOverflowScrollsAndCollapseRestoresReachableContent() async throws {
        _ = NSApplication.shared
        let model = TestContentSize()
        let controller = SettingsWindowController(rootView: TestContent(model: model))
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }
        controller.showWindow(nil)
        try await Task.sleep(for: .milliseconds(100))
        let top = window.frame.maxY
        model.height = 3000
        try await Task.sleep(for: .milliseconds(350))
        let scroll = try XCTUnwrap(window.contentView?.subviews.first as? NSScrollView)
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(window.frame.minY, try XCTUnwrap(window.screen).visibleFrame.minY - 0.5)
        XCTAssertEqual(document.frame.height, 3000, accuracy: 0.5)
        document.scroll(NSPoint(x: 0, y: 2000))
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, 1000)
        model.height = 180
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(scroll.contentView.bounds.minY, 0, accuracy: 0.5)
        XCTAssertEqual(window.contentView!.bounds.height, 180, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
    }

    @MainActor func testTimingSliderKeepsPreciseAccessibleStepsWithoutTicks() {
        let slider = TimingSliderControl()
        slider.minValue = 0
        slider.maxValue = 10
        slider.step = 0.1
        slider.doubleValue = 3
        var value = 3.0
        slider.onChange = { value = $0 }
        XCTAssertEqual(slider.numberOfTickMarks, 0)
        XCTAssertTrue(slider.accessibilityPerformIncrement())
        XCTAssertEqual(value, 3.1, accuracy: 0.001)
        XCTAssertTrue(slider.accessibilityPerformDecrement())
        XCTAssertEqual(value, 3, accuracy: 0.001)
        slider.doubleValue = 10
        XCTAssertTrue(slider.accessibilityPerformIncrement())
        XCTAssertEqual(value, 10)
        slider.isEnabled = false
        XCTAssertFalse(slider.accessibilityPerformDecrement())
        XCTAssertEqual(value, 10)
    }

    @MainActor func testSettingsPresenceSurvivesMinimizeAndEndsOnlyOnClose() async throws {
        let app = NSApplication.shared
        let previousPolicy = app.activationPolicy()
        defer { app.setActivationPolicy(previousPolicy) }
        let menus = ApplicationMenuController()
        var closeCount = 0
        let controller = SettingsWindowController(rootView: Color.clear.frame(width: 380, height: 180),
            onClose: {
                closeCount += 1
                menus.setSettingsOpen(false)
            })
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }

        for expectedCloseCount in 1...2 {
            menus.setSettingsOpen(true)
            controller.showWindow(nil)
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertEqual(app.activationPolicy(), .regular)
            window.miniaturize(nil)
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertTrue(window.isMiniaturized)
            XCTAssertEqual(closeCount, expectedCloseCount - 1)
            menus.restore()
            XCTAssertEqual(app.activationPolicy(), .regular)
            controller.showWindow(nil)
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertFalse(window.isMiniaturized)
            window.close()
            XCTAssertEqual(closeCount, expectedCloseCount)
            XCTAssertEqual(app.activationPolicy(), .accessory)
        }
    }

    @MainActor func testHidingArrowOpensAdvancedAndItsHeightStaysStableWhenHoverLocksAutomaticHiding() async throws {
        _ = NSApplication.shared
        let suite = "LessBarTests.settingsWindow.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let state = MenuBarState()
        state.accessibilityGranted = true
        let controller = SettingsWindowController(rootView: SettingsView(
            preferences: preferences, state: state, supported: true))
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }
        window.orderFrontRegardless()
        try await Task.sleep(nanoseconds: 350_000_000)
        let top = window.frame.maxY
        let foldedHeight = try XCTUnwrap(window.contentView).bounds.height
        preferences.showChevron = false
        try await Task.sleep(nanoseconds: 350_000_000)
        let initialHeight = try XCTUnwrap(window.contentView).bounds.height
        XCTAssertGreaterThan(initialHeight, foldedHeight + 140,
            "Hiding the arrow must expose the reveal controls and timing sliders")
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        preferences.showChevron = true
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, initialHeight, accuracy: 0.5,
            "Showing the arrow must not unexpectedly close Advanced")
        preferences.showOnHover = true
        try await Task.sleep(nanoseconds: 350_000_000)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertEqual(content.bounds.height, initialHeight, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(content.subviews.first).frame.height, content.bounds.height)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        preferences.showOnHover = false
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(content.bounds.height, initialHeight, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
    }

    @MainActor func testHelpRequestWorksBeforeFirstWindowAndAfterCollapseAndClose() async throws {
        _ = NSApplication.shared
        let suite = "LessBarTests.helpMenu.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let state = MenuBarState()
        state.accessibilityGranted = true
        let presentation = SettingsPresentation()
        presentation.showHowToUse()
        let controller = SettingsWindowController(rootView: SettingsView(
            preferences: preferences, state: state, presentation: presentation, supported: true))
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }
        controller.showWindow(nil)
        try await Task.sleep(nanoseconds: 350_000_000)
        let expandedHeight = try XCTUnwrap(window.contentView).bounds.height
        let top = window.frame.maxY
        // Same binding as manually folding the disclosure.
        presentation.helpExpanded = false
        try await Task.sleep(nanoseconds: 350_000_000)
        let foldedHeight = try XCTUnwrap(window.contentView).bounds.height
        XCTAssertGreaterThan(expandedHeight, foldedHeight + 140)
        for closeFirst in [false, true] {
            if closeFirst { window.close() }
            presentation.showHowToUse()
            controller.showWindow(nil)
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, expandedHeight, accuracy: 0.5)
            XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
            XCTAssertTrue(window.isVisible)
            presentation.helpExpanded = false
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, foldedHeight, accuracy: 0.5)
        }
    }

    @MainActor func testHeightAnimationKeepsTopFixedAndContentTopAligned() async throws {
        _ = NSApplication.shared
        let model = TestContentSize()
        let controller = SettingsWindowController(rootView: TestContent(model: model))
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }
        window.orderFrontRegardless()
        try await Task.sleep(nanoseconds: 100_000_000)
        let initialFrame = window.frame
        let initialHeight = try XCTUnwrap(window.contentView).bounds.height
        let anchorTop = window.convertToScreen(model.anchor.convert(model.anchor.bounds, to: nil)).maxY
        XCTAssertEqual(initialHeight, 180, accuracy: 0.5)
        model.height = 320

        var heights: [CGFloat] = []
        for _ in 0..<35 {
            try await Task.sleep(nanoseconds: 10_000_000)
            heights.append(window.frame.height)
            XCTAssertEqual(window.frame.maxY, initialFrame.maxY, accuracy: 0.5)
            XCTAssertEqual(window.frame.minX, initialFrame.minX, accuracy: 0.5)
            XCTAssertEqual(window.convertToScreen(model.anchor.convert(model.anchor.bounds, to: nil)).maxY,
                anchorTop, accuracy: 0.5, "Content must stay fixed throughout the transition")
            let content = try XCTUnwrap(window.contentView)
            XCTAssertTrue(content.isFlipped)
            XCTAssertEqual(try XCTUnwrap(content.subviews.first).frame.minY, 0, accuracy: 0.5)
        }
        let finalHeight = window.frame.height
        XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, 320, accuracy: 0.5)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            XCTAssertTrue(heights.contains { $0 > initialFrame.height + 1 && $0 < finalHeight - 1 },
                "Window height must pass through intermediate sizes")
        }
        for (previous, next) in zip(heights, heights.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next + 0.5, previous)
        }
    }

    @MainActor func testReversingResizeUsesCurrentHeightAndLatestTarget() async throws {
        _ = NSApplication.shared
        let model = TestContentSize()
        let controller = SettingsWindowController(rootView: TestContent(model: model))
        let window = try XCTUnwrap(controller.window)
        defer { window.orderOut(nil) }
        window.orderFrontRegardless()
        try await Task.sleep(nanoseconds: 100_000_000)
        let top = window.frame.maxY
        model.height = 420
        try await Task.sleep(nanoseconds: 90_000_000)
        model.height = 180
        for _ in 0..<35 {
            try await Task.sleep(nanoseconds: 10_000_000)
            XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        }
        XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, 180, accuracy: 0.5)
        let scroll = try XCTUnwrap(window.contentView?.subviews.first as? NSScrollView)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(scroll.documentView?.subviews.first).frame.height, 420)
        // A later expansion must still work after cancelling the previous timer.
        model.height = 300
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, 300, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
    }
}

@MainActor private final class TestContentSize: ObservableObject {
    @Published var height: CGFloat = 180
    let anchor = NSView()
}

private struct TestContent: View {
    @ObservedObject var model: TestContentSize
    var body: some View {
        VStack(spacing: 0) {
            TopAnchor(view: model.anchor).frame(height: 20)
            Color.clear.frame(height: model.height - 20)
        }.frame(width: 380)
    }
}

private struct TopAnchor: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ view: NSView, context: Context) {}
}
