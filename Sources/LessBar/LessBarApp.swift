import AppKit
import SwiftUI

@main
struct LessBarApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// Application lifecycle and settings presentation. Menu bar behavior lives in
/// MenuBarController; recovery windows and timers live in RecoveryController.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var menuBar: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()
        Preferences.migratePrototypeSettings()
        menuBar = MenuBarController(preferences: preferences, onSettings: { [weak self] in self?.showSettings() })
        if !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasShownSetup")
        }
    }

    private func configureApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(title: "LessBar", action: nil, keyEquivalent: "")
        let actions = NSMenu(title: "LessBar")
        let settings = actions.addItem(withTitle: L10n.settings, action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let quit = actions.addItem(withTitle: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        appItem.submenu = actions
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func showSettings() {
        guard let menuBar else { return }
        menuBar.reveal()
        preferences.refreshLoginStatus()
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, state: menuBar.state,
                supported: menuBar.isSupported, toggle: { [weak menuBar] in menuBar?.toggleVisibility() },
                temporaryShow: { [weak menuBar] in menuBar?.temporarilyShowAll() },
                requestAccessibility: { [weak menuBar] in menuBar?.requestAccessibility() })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = L10n.settingsTitle
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.stop()
    }
}
