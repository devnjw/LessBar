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
        Preferences.migratePrototypeSettings()
        menuBar = MenuBarController(onSettings: { [weak self] in self?.showSettings() })
        if !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasShownSetup")
        }
    }

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
                supported: menuBar.isSupported, toggle: { [weak menuBar] in menuBar?.toggleVisibility() })
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
