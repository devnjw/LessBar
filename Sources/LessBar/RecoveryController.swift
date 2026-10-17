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
    private var visibilityTimer: Timer?
    private var retryTimer: Timer?
    private var validation: LayoutRecovery?
    private var visible = false
    private let occupiedFrames: () -> [CGRect]?
    private let visibleMenuBarDisplays: () -> Set<CGDirectDisplayID>
    private var menuBarDisplays: Set<CGDirectDisplayID> = []
    var displayIDs: [UInt32] { sessions.keys.sorted() }
    var visibleFrames: [CGRect] { sessions.values.filter { $0.panel.isVisible }.map { $0.panel.frame } }

    private struct Session {
        let anchor: DisplayAnchor
        let panel: NSPanel
        let button: RecoveryButton
    }

    init(occupiedFrames: @escaping () -> [CGRect]? = { MenuBarOccupancy.statusItemFrames() },
         visibleMenuBarDisplays: @escaping () -> Set<CGDirectDisplayID> = { MenuBarVisibility.visibleDisplayIDs() }) {
        self.occupiedFrames = occupiedFrames
        self.visibleMenuBarDisplays = visibleMenuBarDisplays
        super.init()
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
            // Explicitly accept clicks in the transparent padding as well as
            // the chevron's painted pixels. The default uses pixel hit testing.
            panel.ignoresMouseEvents = false
            panel.hasShadow = false
            panel.animationBehavior = .none
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            let button = RecoveryButton(frame: NSRect(origin: .zero, size: anchor.control.size))
            button.isBordered = false
            button.title = ""
            ChevronAppearance.configure(button, collapsed: true)
            button.imageFrame = anchor.imageFrame.map {
                $0.offsetBy(dx: -anchor.control.minX, dy: -anchor.control.minY)
            }
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

    /// Present the replacement before removing the native chevron. Keep its
    /// old direction until collapse completes so opposite glyphs never overlap.
    func handoffToCollapsed(_ collapse: () -> Bool) -> Bool {
        guard !sessions.isEmpty,
              Set(sessions.keys) == Set(NSScreen.screens.map(MenuBarGeometry.displayID)) else { return false }
        if visible {
            menuBarDisplays = visibleMenuBarDisplays()
            let shown = sessions.values.filter { menuBarDisplays.contains($0.anchor.displayID) }
            guard let occupied = shown.isEmpty ? [] : occupiedFrames() else { return false }
            var placements: [(Session, CGRect)] = []
            for session in shown {
                guard let rect = LayoutSafety.recoveryFrame(anchor: session.anchor.control,
                    available: session.anchor.available, occupied: occupied) else { return false }
                placements.append((session, rect))
            }
            // Check every display before showing any panel or changing the
            // native boundary. Unknown/unsafe geometry leaves it expanded.
            for (session, rect) in placements {
                ChevronAppearance.configure(session.button, collapsed: false)
                session.panel.setFrame(rect, display: false)
                session.panel.display()
                session.panel.orderFrontRegardless()
            }
            guard shown.allSatisfy({ $0.panel.isVisible }) else { stop(); return false }
        }
        guard collapse() else { stop(); return false }
        for session in sessions.values {
            ChevronAppearance.configure(session.button, collapsed: true)
            if session.panel.isVisible { session.panel.display() }
        }
        return true
    }

    func startMonitoring() {
        guard !sessions.isEmpty, safetyTimer == nil else { return }
        validation = LayoutRecovery(now: ProcessInfo.processInfo.systemUptime)
        safetyTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                self.checkLayoutSafety()
            }
        }
        RunLoop.main.add(safetyTimer!, forMode: .common)
        visibilityTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                self.refreshVisibility()
            }
        }
        RunLoop.main.add(visibilityTimer!, forMode: .common)
        refreshVisibility()
        scheduleRetry()
    }

    func stop() {
        safetyTimer?.invalidate(); safetyTimer = nil
        visibilityTimer?.invalidate(); visibilityTimer = nil
        retryTimer?.invalidate(); retryTimer = nil
        validation = nil
        sessions.values.forEach { $0.panel.orderOut(nil) }
        sessions.removeAll()
        recoveryButton = nil
        menuBarDisplays = []
    }

    @objc func refreshVisibility() {
        guard visible, !sessions.isEmpty, visibleMenuBarDisplays() != menuBarDisplays else { return }
        checkLayoutSafety()
    }

    @objc private func checkLayoutSafety() {
        retryTimer?.invalidate(); retryTimer = nil
        guard var validation else { return }
        let activeDisplays = Set(NSScreen.screens.map(MenuBarGeometry.displayID))
        var safe = sessions.keys.allSatisfy { activeDisplays.contains($0) }
        if visible {
            menuBarDisplays = visibleMenuBarDisplays()
            // Hidden menu bars are intentional, not failed recovery controls.
            // Keep the collapse state and validate only displays with a menu bar.
            let shown = sessions.values.filter { menuBarDisplays.contains($0.anchor.displayID) }
            for session in sessions.values where !menuBarDisplays.contains(session.anchor.displayID) {
                session.panel.orderOut(nil)
            }
            guard let occupied = shown.isEmpty ? [] : occupiedFrames() else { onReveal(); return }
            for session in shown {
                if let rect = LayoutSafety.recoveryFrame(anchor: session.anchor.control,
                    available: session.anchor.available, occupied: occupied) {
                    if session.panel.frame != rect { session.panel.setFrame(rect, display: true) }
                    if !session.panel.isVisible { session.panel.orderFrontRegardless() }
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
        retryTimer = Timer(timeInterval: LayoutRecovery.retryInterval, repeats: false) { [weak self] timer in
            let timerID = ObjectIdentifier(timer)
            MainActor.assumeIsolated {
                guard let self, self.retryTimer.map(ObjectIdentifier.init) == timerID else { return }
                self.checkLayoutSafety()
            }
        }
        RunLoop.main.add(retryTimer!, forMode: .common)
    }
}
