import AppKit

/// Temporarily makes our minimal menu the active menu only when space is short.
@MainActor
final class ApplicationMenuController {
    private var previousApp: NSRunningApplication?
    private var originalMenu: NSMenu?
    private var active = false
    private var settingsOpen = false

    func setSettingsOpen(_ open: Bool) {
        settingsOpen = open
        // Hand menu ownership back before presenting settings. A later icon
        // collapse must not demote an app whose settings are still open.
        restore()
        NSApp.setActivationPolicy(open ? .regular : .accessory)
    }

    func makeRoomIfNeeded(enabled: Bool, screen: NSScreen?, settingsVisible: Bool) {
        guard enabled, !active, !settingsOpen, !settingsVisible, let screen,
              !NSApp.currentSystemPresentationOptions.contains(.fullScreen),
              !NSApp.currentSystemPresentationOptions.contains(.autoHideMenuBar),
              !NSApp.currentSystemPresentationOptions.contains(.hideMenuBar),
              let menus = MenuBarGeometry.applicationMenuFrames(on: screen),
              let occupied = MenuBarOccupancy.statusItemFrames(),
              let menuRight = menus.map(\.maxX).max(),
              let iconLeft = occupied.filter({ MenuBarGeometry.menuBarRect(screen).intersects($0) }).map(\.minX).min(),
              iconLeft <= menuRight + 8 else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        originalMenu = NSApp.mainMenu
        NSApp.mainMenu = NSMenu()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        active = true
    }

    func restore() {
        guard active else { return }
        let stillOwnFocus = NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        NSApp.mainMenu = originalMenu
        NSApp.setActivationPolicy(settingsOpen ? .regular : .accessory)
        if !settingsOpen, stillOwnFocus, let previousApp, !previousApp.isTerminated {
            previousApp.activate(options: [.activateIgnoringOtherApps])
        }
        previousApp = nil
        originalMenu = nil
        active = false
    }
}
