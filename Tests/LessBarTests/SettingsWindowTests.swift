import AppKit
import SwiftUI
import XCTest
@testable import LessBar

final class SettingsWindowTests: XCTestCase {
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

    @MainActor func testRealSettingsHeightFollowsHoverExplanationAndRestores() async throws {
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
        let initialHeight = try XCTUnwrap(window.contentView).bounds.height
        preferences.showOnHover = true
        try await Task.sleep(nanoseconds: 350_000_000)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertGreaterThan(content.bounds.height, initialHeight)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(content.subviews.first).frame.height, content.bounds.height)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
        preferences.showOnHover = false
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(content.bounds.height, initialHeight, accuracy: 0.5)
        XCTAssertEqual(window.frame.maxY, top, accuracy: 0.5)
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
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(window.contentView?.subviews.first).frame.height, 420)
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
