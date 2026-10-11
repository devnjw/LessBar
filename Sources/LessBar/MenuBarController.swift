import AppKit
import Combine

@MainActor
final class MenuBarState: ObservableObject {
    @Published var isCollapsed = false
}

/// Coordinates the native status item, its menu, and the separate reveal control.
@MainActor
final class MenuBarController: NSObject {
    let state = MenuBarState()
    var isSupported: Bool { engine.isSupported }
    private let toggle: NSStatusItem
    private let engine: any MenuBarEngine
    private let recovery = RecoveryController()
    private let onSettings: () -> Void

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        let item = NSStatusBar.system.statusItem(withLength: LayoutSafety.controlWidth)
        toggle = item
        engine = LengthMenuBarEngine(toggle: item)
        super.init()
        // Preserve placement when upgrading from the personal prototype.
        toggle.autosaveName = "TidyBar.Toggle"
        toggle.isVisible = true
        toggle.button?.target = self
        toggle.button?.action = #selector(clicked)
        toggle.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        recovery.onReveal = { [weak self] in self?.reveal() }
        recovery.onContextMenu = { [weak self] in self?.showContextMenu() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        updateButton()
    }

    func toggleVisibility() {
        if engine.isCollapsed { reveal(); return }
        guard isSupported else { onSettings(); return }
        guard engine.canCollapse, let button = toggle.button,
              recovery.prepare(for: button) else {
            onSettings()
            let alert = NSAlert()
            alert.messageText = L10n.positionUnavailable
            alert.informativeText = L10n.positionRecovery
            alert.addButton(withTitle: L10n.ok)
            alert.runModal()
            return
        }
        engine.setCollapsed(true)
        guard engine.isCollapsed else { reveal(); return }
        recovery.startMonitoring()
        updateButton()
    }

    func reveal() {
        recovery.stop()
        engine.setCollapsed(false)
        toggle.isVisible = true
        updateButton()
    }

    func stop() {
        reveal()
        NotificationCenter.default.removeObserver(self)
        NSStatusBar.system.removeStatusItem(toggle)
    }

    private func updateButton() {
        state.isCollapsed = engine.isCollapsed
        toggle.button?.image = engine.isCollapsed ? nil : NSImage(
            systemSymbolName: "chevron.right", accessibilityDescription: L10n.hideIcons)
        toggle.button?.setAccessibilityLabel(engine.isCollapsed ? L10n.showIcons : L10n.hideIcons)
        toggle.button?.toolTip = L10n.toggleTooltip
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showContextMenu() }
        else { toggleVisibility() }
    }

    private func showContextMenu() {
        guard let button = recovery.recoveryButton ?? toggle.button else { return }
        let menu = NSMenu()
        let settings = menu.addItem(withTitle: L10n.settings, action: #selector(showSettings), keyEquivalent: "")
        settings.target = self
        // A local action avoids AppKit's automatic terminate icon.
        let quit = menu.addItem(withTitle: L10n.quit, action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        if recovery.recoveryButton != nil {
            menu.popUp(positioning: nil,
                at: NSPoint(x: button.bounds.minX, y: button.isFlipped ? button.bounds.maxY : button.bounds.minY),
                in: button)
        } else {
            toggle.menu = menu
            defer { toggle.menu = nil }
            button.performClick(nil)
        }
    }

    @objc private func screenChanged() { reveal() }
    @objc private func showSettings() { onSettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
