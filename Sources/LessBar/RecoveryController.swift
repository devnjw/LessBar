import AppKit

/// One independently positioned recovery control per native menu bar. Every
/// control invokes the same shared reveal action; none covers occupied icons.
@MainActor
final class RecoveryController: NSObject {
    var onReveal: () -> Void = {}
    var onContextMenu: (CGPoint) -> Void = { _ in }
    private(set) var recoveryButton: NSButton?
    private var sessions: [CGDirectDisplayID: Session] = [:]
    private var safetyTimer: Timer?
    private var retryTimer: Timer?
    private var validation: LayoutRecovery?
    private var visible = false
    var displayIDs: [UInt32] { sessions.keys.sorted() }
    var visibleFrames: [CGRect] { sessions.values.filter { $0.panel.isVisible }.map { $0.panel.frame } }

    private struct Session {
        let anchor: DisplayAnchor
        let panel: NSPanel
        let button: RecoveryButton
    }

    func prepare(anchors: [DisplayAnchor], showControls: Bool) -> Bool {
        stop()
        guard Set(anchors.map(\.displayID)) == Set(NSScreen.screens.map(MenuBarGeometry.displayID)),
              !anchors.isEmpty else { return false }
        visible = showControls
        for anchor in anchors {
            let panel = NSPanel(contentRect: anchor.control,
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = L10n.recoveryTitle
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            let button = RecoveryButton(frame: NSRect(origin: .zero, size: anchor.control.size))
            button.isBordered = false
            button.title = ""
            button.imagePosition = .imageOnly
            button.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: L10n.showIcons)
            button.setAccessibilityLabel(L10n.showIcons)
            button.toolTip = L10n.recoveryTooltip
            button.onReveal = { [weak self, weak panel] in
                DispatchQueue.main.async { [weak self, weak panel] in
                    guard let self, let panel, self.sessions.values.contains(where: { $0.panel === panel }) else { return }
                    self.onReveal()
                }
            }
            button.onContextMenu = { [weak self] in self?.onContextMenu(NSEvent.mouseLocation) }
            button.target = button
            button.action = #selector(RecoveryButton.revealFromAccessibility)
            panel.contentView = button
            sessions[anchor.displayID] = Session(anchor: anchor, panel: panel, button: button)
        }
        recoveryButton = sessions.values.first?.button
        return true
    }

    func startMonitoring() {
        guard !sessions.isEmpty else { return }
        validation = LayoutRecovery(now: ProcessInfo.processInfo.systemUptime)
        safetyTimer = Timer(timeInterval: 0.5, target: self,
            selector: #selector(checkLayoutSafety), userInfo: nil, repeats: true)
        RunLoop.main.add(safetyTimer!, forMode: .common)
        scheduleRetry()
    }

    func stop() {
        safetyTimer?.invalidate(); safetyTimer = nil
        retryTimer?.invalidate(); retryTimer = nil
        validation = nil
        sessions.values.forEach { $0.panel.orderOut(nil) }
        sessions.removeAll()
        recoveryButton = nil
    }

    @objc private func checkLayoutSafety() {
        retryTimer?.invalidate(); retryTimer = nil
        guard var validation else { return }
        let activeDisplays = Set(NSScreen.screens.map(MenuBarGeometry.displayID))
        var safe = sessions.keys.allSatisfy { activeDisplays.contains($0) }
        if visible {
            guard let occupied = MenuBarOccupancy.statusItemFrames() else { onReveal(); return }
            for session in sessions.values {
                if let rect = LayoutSafety.recoveryFrame(anchor: session.anchor.control,
                    available: session.anchor.available, occupied: occupied) {
                    session.panel.setFrame(rect, display: true)
                    session.panel.orderFrontRegardless()
                    safe = safe && session.panel.isVisible
                } else {
                    session.panel.orderOut(nil)
                    safe = false
                }
            }
        } else {
            sessions.values.forEach { $0.panel.orderOut(nil) }
        }
        let action = validation.evaluate(controlIsSafe: safe, now: ProcessInfo.processInfo.systemUptime)
        self.validation = validation
        switch action {
        case .monitor: break
        case .retry: scheduleRetry()
        case .reveal: onReveal()
        }
    }

    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = Timer(timeInterval: LayoutRecovery.retryInterval, target: self,
            selector: #selector(checkLayoutSafety), userInfo: nil, repeats: false)
        RunLoop.main.add(retryTimer!, forMode: .common)
    }
}
