import AppKit
import SwiftUI

/// Owns window sizing separately from SwiftUI's intrinsic-height changes.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onClose: () -> Void
    private let hosting = NSHostingController(rootView: AnyView(EmptyView()))
    private let scrollView = NSScrollView()
    private let scrollDocument = SettingsContentContainer()
    private var contentSize = NSSize.zero
    private var resizeTimer: Timer?
    private var resizeVersion = 0
    private var layoutHeight: CGFloat = NSScreen.screens.map(\.frame.height).max() ?? 1200

    init<Content: View>(rootView: Content, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 350),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        window.title = L10n.settingsTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        // No intrinsic min/max constraints may resize the window independently.
        hosting.sizingOptions = []
        hosting.rootView = AnyView(rootView)
        let initialSize = hosting.sizeThatFits(in: NSSize(width: 380, height: CGFloat.greatestFiniteMagnitude))
        // Measure a child at its ideal height, not the hosting view's current
        // viewport height. A top-aligned wrapper keeps root layout unclamped.
        hosting.rootView = AnyView(VStack(spacing: 0) {
            rootView.fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: SettingsContentSize.self, value: geometry.size)
                })
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onPreferenceChange(SettingsContentSize.self) { [weak self] size in
            Task { @MainActor [weak self] in self?.updateContentSize(size) }
        })
        let container = SettingsContentContainer()
        container.autoresizesSubviews = false
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        scrollDocument.autoresizesSubviews = false
        scrollDocument.wantsLayer = true
        scrollDocument.layer?.masksToBounds = true
        scrollDocument.addSubview(hosting.view)
        scrollView.documentView = scrollDocument
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.frame = container.bounds
        container.autoresizesSubviews = true
        container.addSubview(scrollView)
        window.contentView = container
        if let screen = window.screen ?? NSScreen.main {
            window.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.midX - 190, y: screen.visibleFrame.maxY))
        }
        updateContentSize(initialSize)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        if window?.isMiniaturized == true { window?.deminiaturize(sender) }
        updateContentSize(contentSize, force: true)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        updateContentSize(contentSize, force: true)
    }

    private func updateContentSize(_ size: NSSize, force: Bool = false) {
        guard let window, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }
        let size = NSSize(width: ceil(size.width), height: ceil(size.height))
        guard force || size != contentSize else { return }
        contentSize = size
        // Leave room for the next expansion before SwiftUI lays it out. Resizing
        // this viewport to the collapsed height makes an expanding VStack briefly
        // overflow and recenter before its new measurement reaches this callback.
        layoutHeight = max(layoutHeight, size.height)
        hosting.view.frame = NSRect(origin: .zero,
            size: NSSize(width: size.width, height: layoutHeight))
        scrollDocument.setFrameSize(size)
        let idealHeight = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).height
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let height = Self.fittingHeight(idealHeight, top: window.frame.maxY, visibleFrame: visibleFrame)
        resizeTimer?.invalidate()
        resizeTimer = nil
        resizeVersion += 1

        guard window.isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            setHeight(height, width: size.width)
            return
        }
        let initialHeight = window.frame.height
        guard abs(initialHeight - height) > 0.5 else { return }
        let started = ProcessInfo.processInfo.systemUptime
        let version = resizeVersion
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                guard self.resizeVersion == version else { return }
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - started) / 0.22)
                let eased = progress * progress * (3 - 2 * progress)
                self.setHeight(initialHeight + (height - initialHeight) * eased, width: size.width)
                if progress == 1 {
                    self.resizeTimer?.invalidate()
                    self.resizeTimer = nil
                }
            }
        }
        resizeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Preserve the top edge and leave the Dock/menu bar outside the viewport.
    static func fittingHeight(_ idealHeight: CGFloat, top: CGFloat, visibleFrame: NSRect) -> CGFloat {
        min(idealHeight, max(1, min(top, visibleFrame.maxY) - visibleFrame.minY))
    }

    private func setHeight(_ height: CGFloat, width: CGFloat) {
        guard let window else { return }
        var frame = window.frame
        let top = min(frame.maxY, window.screen?.visibleFrame.maxY ?? frame.maxY)
        frame.origin.y = top - height
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true)
        // Clamp a previous scroll offset when a disclosure removes content.
        scrollView.contentView.scroll(to: scrollView.contentView.constrainBoundsRect(scrollView.contentView.bounds).origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private final class SettingsContentContainer: NSView {
    override var isFlipped: Bool { true }
}

private struct SettingsContentSize: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        // Native controls can contribute the default size after our reporter.
        // A default value must never replace the measured content height.
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}
