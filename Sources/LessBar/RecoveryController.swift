import AppKit

/// Owns the temporary reveal control and its bounded layout validation lifecycle.
/// No timer survives a reveal, a display change or the start of another session.
@MainActor
final class RecoveryController: NSObject {
    var onReveal: () -> Void = {}
    var onContextMenu: () -> Void = {}
    private(set) var recoveryButton: NSButton?
    private var recoveryPanel: NSPanel?
    private var recoveryAnchor: CGRect?
    private var recoveryAvailableArea: CGRect?
    private var layoutRecovery: LayoutRecovery?
    private var layoutRetryTimer: Timer?
    private var safetyTimer: Timer?

    func prepare(for button: NSStatusBarButton) -> Bool {
        stop()
        guard let window = button.window, let screen = window.screen else { return false }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        recoveryAnchor = rect
        // Stay on the right side of a notched display. Elsewhere, limit movement
        // to the right half so recovery never covers application menu titles.
        let leftEdge = min(rect.minX, screen.frame.midX)
        recoveryAvailableArea = screen.auxiliaryTopRightArea ?? CGRect(
            x: leftEdge, y: screen.frame.minY, width: screen.frame.maxX - leftEdge,
            height: screen.frame.height)
        // A separate window stays clickable even if AppKit drops the oversized
        // status item's native button. Create it BEFORE changing the length.
        let panel = NSPanel(contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = L10n.recoveryTitle
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        let recovery = RecoveryButton(frame: NSRect(origin: .zero, size: rect.size))
        recovery.isBordered = false
        recovery.title = ""
        recovery.imagePosition = .imageOnly
        recovery.imageScaling = .scaleProportionallyDown
        recovery.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: L10n.showIcons)
        recovery.appearance = button.effectiveAppearance
        recovery.contentTintColor = button.contentTintColor ?? .labelColor
        recovery.setAccessibilityLabel(L10n.showIcons)
        recovery.toolTip = L10n.recoveryTooltip
        // Recovery always reveals; it must never toggle back to collapsed if
        // duplicate or delayed events arrive during the window transition.
        recovery.onReveal = { [weak self, weak panel] in
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let self, let panel, self.recoveryPanel === panel else { return }
                self.onReveal()
            }
        }
        recovery.onContextMenu = { [weak self] in self?.onContextMenu() }
        recovery.target = recovery
        recovery.action = #selector(RecoveryButton.revealFromAccessibility)
        panel.contentView = recovery
        recoveryPanel = panel
        recoveryButton = recovery
        return true
    }

    func startMonitoring() {
        guard recoveryPanel != nil else { return }
        layoutRecovery = LayoutRecovery(now: ProcessInfo.processInfo.systemUptime)
        let timer = Timer(timeInterval: 0.5, target: self,
            selector: #selector(checkLayoutSafety), userInfo: nil, repeats: true)
        safetyTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        scheduleLayoutRetry()
    }

    func stop() {
        safetyTimer?.invalidate()
        safetyTimer = nil
        layoutRetryTimer?.invalidate()
        layoutRetryTimer = nil
        layoutRecovery = nil
        recoveryPanel?.orderOut(nil)
        recoveryPanel = nil
        recoveryButton = nil
        recoveryAnchor = nil
        recoveryAvailableArea = nil
    }

    @objc private func checkLayoutSafety() {
        layoutRetryTimer?.invalidate()
        layoutRetryTimer = nil
        guard var validation = layoutRecovery,
              let panel = recoveryPanel else { return }
        let placed = placeRecoveryPanel()
        if placed {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else {
            // Never cover a sharing indicator while waiting for a fresh layout.
            panel.orderOut(nil)
        }
        let action = validation.evaluate(controlIsSafe: placed && panel.isVisible,
            now: ProcessInfo.processInfo.systemUptime)
        layoutRecovery = validation
        switch action {
        case .monitor: break
        case .retry: scheduleLayoutRetry()
        case .reveal: onReveal()
        }
    }

    private func scheduleLayoutRetry() {
        layoutRetryTimer?.invalidate()
        let timer = Timer(timeInterval: LayoutRecovery.retryInterval, target: self,
            selector: #selector(retryLayout(_:)), userInfo: nil, repeats: false)
        layoutRetryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func retryLayout(_ timer: Timer) {
        // A cancelled timer from an earlier collapse must not affect a new one.
        guard layoutRetryTimer === timer else { return }
        checkLayoutSafety()
    }

    private func placeRecoveryPanel() -> Bool {
        guard let panel = recoveryPanel, let anchor = recoveryAnchor,
              let area = recoveryAvailableArea,
              let occupied = MenuBarOccupancy.statusItemFrames(),
              let frame = LayoutSafety.recoveryFrame(anchor: anchor, available: area,
                                                      occupied: occupied) else { return false }
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        return true
    }

}
