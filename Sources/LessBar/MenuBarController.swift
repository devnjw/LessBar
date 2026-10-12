import AppKit
@preconcurrency import ApplicationServices
import Combine

@MainActor
final class MenuBarState: ObservableObject {
    @Published var isCollapsed = false
    @Published var accessibilityGranted = false
    @Published var feedback = ""
}

/// One shared visibility state for every native mirrored menu bar. Geometry and
/// recovery controls are per display; preferences and timers are application-wide.
@MainActor
final class MenuBarController: NSObject {
    let state = MenuBarState()
    var isSupported: Bool { engine.isSupported }
    private let preferences: Preferences
    private let toggle: NSStatusItem
    private let engine: LengthMenuBarEngine
    private let recovery = RecoveryController()
    private let applicationMenus = ApplicationMenuController()
    private let onSettings: () -> Void
    private var preferenceObserver: AnyCancellable?
    private var interactionTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var policy = InteractionPolicy()
    private var temporaryRestoreCollapsed: Bool?
    private var editing = false
    private var wasCollapsedBeforeEditing = false
    private var clickPending = false
    private var dragPending = false
    private var dragOrigin: CGPoint?
    private var editingEndAt: TimeInterval?
    private var geometryAt: TimeInterval = 0
    private var cachedMenus: [UInt32: [CGRect]] = [:]
    private var cachedStatusFrames: [CGRect]?
    private var nativeMenuOpen = false
    private var lastAnchors: [DisplayAnchor] = []
    private var pendingLayoutCollapse: DispatchWorkItem?

    init(preferences: Preferences, onSettings: @escaping () -> Void) {
        self.preferences = preferences
        self.onSettings = onSettings
        let item = NSStatusBar.system.statusItem(withLength: LayoutSafety.controlWidth)
        item.autosaveName = "TidyBar.Toggle"
        item.isVisible = true
        toggle = item
        engine = LengthMenuBarEngine(toggle: item)
        super.init()
        configureNativeButton(item)
        recovery.onReveal = { [weak self] in self?.reveal() }
        recovery.onContextMenu = { [weak self] point in self?.showContextMenu(at: point) }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        applyPreferences()
        preferenceObserver = preferences.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.applyPreferences() }
        }
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .leftMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.observe(event) }
            return event
        }
        interactionTimer = Timer(timeInterval: 0.05, target: self,
            selector: #selector(checkInteraction), userInfo: nil, repeats: true)
        RunLoop.main.add(interactionTimer!, forMode: .common)
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private var configuration: InteractionPolicy.Configuration {
        .init(showOnClick: preferences.showOnClick, showOnHover: preferences.showOnHover,
              hoverDelay: preferences.hoverDelay, autoRehide: preferences.autoRehide,
              rehideStrategy: preferences.rehideStrategy, rehideDelay: preferences.rehideDelay,
              showAllOnCommandDrag: preferences.showAllOnCommandDrag,
              enableAlwaysHidden: preferences.enableAlwaysHidden,
              temporaryShowDelay: preferences.temporaryShowDelay)
    }

    private var settingsPinned: Bool {
        NSApp.isActive && NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
    }

    private func configureNativeButton(_ item: NSStatusItem) {
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func applyPreferences() {
        let collapsed = engine.isCollapsed
        recovery.stop()
        engine.configure(showDividers: preferences.showSectionDividers,
            alwaysHiddenEnabled: preferences.enableAlwaysHidden, editing: editing)
        if let secondary = engine.secondaryItem { configureNativeButton(secondary) }
        if !preferences.hideApplicationMenus { applicationMenus.restore() }
        if collapsed { restartRecovery() }
        geometryAt = 0
        updateButton()
    }

    func toggleVisibility() {
        if engine.isCollapsed { reveal() }
        else { collapse(reportFailure: true) }
    }

    private func collapse(reportFailure: Bool = false) {
        guard isSupported else { return }
        if !engine.validateBoundaryOrder() {
            engine.reveal(all: true)
            state.feedback = L10n.boundaryOrder
            policy.didReveal(now: now, temporaryAll: true, temporaryDelay: preferences.temporaryShowDelay)
            updateButton()
            return
        }
        let anchors = engine.anchors
        lastAnchors = anchors
        guard !anchors.isEmpty,
              recovery.prepare(anchors: anchors, showControls: preferences.showSectionDividers),
              engine.setCollapsed(true) else {
            recovery.stop()
            if reportFailure { state.feedback = L10n.positionRecovery }
            policy.didReveal(now: now)
            return
        }
        applicationMenus.restore()
        temporaryRestoreCollapsed = nil
        policy.didCollapse(pointerInMenuBar: MenuBarGeometry.screen(at: NSEvent.mouseLocation) != nil)
        recovery.startMonitoring()
        state.feedback = ""
        updateButton()
    }

    private func restartRecovery() {
        let anchors = lastAnchors.isEmpty ? engine.anchors : lastAnchors
        if recovery.prepare(anchors: anchors, showControls: preferences.showSectionDividers) {
            recovery.startMonitoring()
        } else { reveal() }
    }

    func reveal(all: Bool = false, temporary: Bool = false) {
        pendingLayoutCollapse?.cancel(); pendingLayoutCollapse = nil
        editingEndAt = nil
        if !all { temporaryRestoreCollapsed = nil }
        recovery.stop()
        engine.reveal(all: all)
        toggle.isVisible = true
        policy.didReveal(now: now, temporaryAll: temporary,
            temporaryDelay: preferences.temporaryShowDelay)
        updateButton()
        if !editing {
            applicationMenus.makeRoomIfNeeded(enabled: preferences.hideApplicationMenus,
                screen: MenuBarGeometry.screen(at: NSEvent.mouseLocation), settingsVisible: settingsPinned)
        }
    }

    func temporarilyShowAll() {
        if temporaryRestoreCollapsed == nil { temporaryRestoreCollapsed = engine.isCollapsed }
        reveal(all: true, temporary: true)
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        state.accessibilityGranted = AXIsProcessTrusted()
    }

    func stop() {
        pendingLayoutCollapse?.cancel(); pendingLayoutCollapse = nil
        interactionTimer?.invalidate(); interactionTimer = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil; localMonitor = nil
        preferenceObserver = nil
        recovery.stop()
        applicationMenus.restore()
        engine.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NSStatusBar.system.removeStatusItem(toggle)
    }

    private func updateButton() {
        state.isCollapsed = engine.isCollapsed
        state.accessibilityGranted = AXIsProcessTrusted()
        for item in [toggle, engine.secondaryItem].compactMap({ $0 }) {
            item.button?.title = editing ? "│" : ""
            item.button?.image = !editing && preferences.showSectionDividers && !engine.isCollapsed
                ? NSImage(systemSymbolName: "chevron.right", accessibilityDescription: L10n.hideIcons) : nil
            item.button?.setAccessibilityLabel(engine.isCollapsed ? L10n.showIcons : L10n.hideIcons)
            item.button?.toolTip = L10n.toggleTooltip
        }
    }

    private func observe(_ event: NSEvent) {
        if event.window?.level.rawValue == Int(CGWindowLevelForKey(.statusWindow)) ||
           event.window?.title == L10n.recoveryTitle { return }
        let point = NSEvent.mouseLocation
        guard MenuBarGeometry.screen(at: point) != nil else { return }
        if event.type == .leftMouseDragged && event.modifierFlags.contains(.command) {
            dragPending = true
        }
        if event.type == .leftMouseUp && !event.modifierFlags.contains(.command) {
            clickPending = true
            geometryAt = 0
        }
        if event.type == .rightMouseUp && isEmpty(point) { showContextMenu(at: point) }
    }

    private func refreshGeometry() {
        engine.synchronizeMirrorSpacing()
        geometryAt = now
        cachedStatusFrames = MenuBarOccupancy.statusItemFrames()
        cachedMenus.removeAll()
        if AXIsProcessTrusted() {
            for screen in NSScreen.screens {
                if let menus = MenuBarGeometry.applicationMenuFrames(on: screen) {
                    cachedMenus[MenuBarGeometry.displayID(screen)] = menus
                }
            }
        }
        nativeMenuOpen = MenuBarOccupancy.hasOpenMenu()
        state.accessibilityGranted = AXIsProcessTrusted()
    }

    private func isEmpty(_ point: CGPoint) -> Bool {
        guard let screen = MenuBarGeometry.screen(at: point) else { return false }
        let ownControls = (MenuBarOccupancy.ownStatusItemFrames() ?? []).filter { $0.width > 1 && $0.width < 100 }
        return MenuBarGeometry.isEmpty(point: point, menu: MenuBarGeometry.menuBarRect(screen),
            applicationMenus: cachedMenus[MenuBarGeometry.displayID(screen)],
            statusItems: cachedStatusFrames.map { $0 + ownControls })
    }

    @objc private func checkInteraction() {
        if now - geometryAt > 0.2 { refreshGeometry() }
        let point = NSEvent.mouseLocation
        let screen = MenuBarGeometry.screen(at: point)
        let display = screen.map(MenuBarGeometry.displayID)
        let command = NSEvent.modifierFlags.contains(.command)
        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
        if mouseDown && command && screen != nil {
            if let origin = dragOrigin {
                if hypot(point.x - origin.x, point.y - origin.y) >= 6 { dragPending = true }
            } else { dragOrigin = point }
        }
        if !mouseDown && !command { dragOrigin = nil }
        let input = InteractionPolicy.Input(now: now, menuDisplayID: display,
            emptyDisplayID: isEmpty(point) ? display : nil, clickOnEmpty: clickPending,
            mouseDown: mouseDown, command: command, menuOpen: nativeMenuOpen,
            dragInProgress: dragPending && mouseDown, settingsPinned: settingsPinned || !state.feedback.isEmpty)
        clickPending = false
        for action in policy.step(input, configuration: configuration) {
            switch action {
            case .revealNormal: reveal()
            case .revealAll: temporarilyShowAll()
            case .beginEditing:
                wasCollapsedBeforeEditing = engine.isCollapsed
                editing = true
                recovery.stop()
                engine.configure(showDividers: preferences.showSectionDividers,
                    alwaysHiddenEnabled: preferences.enableAlwaysHidden, editing: true)
                engine.reveal(all: true)
                updateButton()
            case .endEditing(let didDrag):
                editing = false
                engine.configure(showDividers: preferences.showSectionDividers,
                    alwaysHiddenEnabled: preferences.enableAlwaysHidden, editing: false)
                if didDrag || wasCollapsedBeforeEditing { editingEndAt = now + 0.3 }
                else { reveal() }
                updateButton()
            case .collapse: collapse()
            case .endTemporaryAll:
                let restoreCollapsed = temporaryRestoreCollapsed ?? false
                temporaryRestoreCollapsed = nil
                if restoreCollapsed { collapse() }
                else {
                    engine.hideAlwaysHidden()
                    policy.didReveal(now: now)
                    updateButton()
                }
            }
        }
        if let deadline = editingEndAt, now >= deadline, !mouseDown, !command {
            editingEndAt = nil
            collapse(reportFailure: true)
        }
        if !editing && !mouseDown { dragPending = false }
    }

    private func showContextMenu(at point: CGPoint) {
        let menu = NSMenu()
        let settings = menu.addItem(withTitle: L10n.settings, action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        if preferences.enableAlwaysHidden {
            let all = menu.addItem(withTitle: L10n.temporaryShowAll, action: #selector(showAll), keyEquivalent: "")
            all.target = self
        }
        let quit = menu.addItem(withTitle: L10n.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showContextMenu(at: NSEvent.mouseLocation) }
        else { toggleVisibility() }
    }
    @objc private func screenChanged() {
        let collapsed = engine.isCollapsed
        reveal()
        geometryAt = 0
        lastAnchors = []
        if collapsed {
            let work = DispatchWorkItem { [weak self] in self?.collapse() }
            pendingLayoutCollapse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }
    @objc private func spaceChanged() { geometryAt = 0 }
    @objc private func showSettings() { onSettings() }
    @objc private func showAll() { temporarilyShowAll() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
