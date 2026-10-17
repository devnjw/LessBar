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
    private var settingsWindow: SettingsWindowController?
    private let settingsPresentation = SettingsPresentation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationMenu()
        preferences.onLanguageChange = { [weak self] previous in
            self?.updateLanguage(from: previous)
        }
        Preferences.migratePrototypeSettings()
        menuBar = MenuBarController(preferences: preferences,
            onSettings: { [weak self] in self?.showSettings() },
            onHowToUse: { [weak self] in self?.showSettings(showHowToUse: true) })
        if !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasShownSetup")
        }
    }

    private func configureApplicationMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem(title: L10n.appName, action: nil, keyEquivalent: "")
        let actions = NSMenu(title: L10n.appName)
        let settings = actions.addItem(withTitle: L10n.settings, action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        let help = actions.addItem(withTitle: L10n.howToUse, action: #selector(openHowToUse), keyEquivalent: "")
        help.target = self
        let quit = actions.addItem(withTitle: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        appItem.submenu = actions
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    private func updateLanguage(from previous: AppLanguage) {
        configureApplicationMenu()
        settingsWindow?.window?.title = L10n.settingsTitle
        preferences.refreshLoginStatus()
        menuBar?.refreshLanguage(from: previous)
    }

    @objc private func openSettings() { showSettings() }
    @objc private func openHowToUse() { showSettings(showHowToUse: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func showSettings(showHowToUse: Bool = false) {
        guard let menuBar else { return }
        if showHowToUse { settingsPresentation.showHowToUse() }
        menuBar.setSettingsOpen(true)
        menuBar.retrySharingPlacement()
        if preferences.enableAlwaysHidden {
            menuBar.temporarilyShowAll()
        } else {
            menuBar.reveal()
        }
        preferences.refreshLoginStatus()
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, state: menuBar.state,
                presentation: settingsPresentation,
                supported: menuBar.isSupported,
                requestAccessibility: { [weak menuBar] in menuBar?.requestAccessibility() })
            settingsWindow = SettingsWindowController(rootView: view, onClose: { [weak menuBar] in
                menuBar?.setSettingsOpen(false)
            })
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.showWindow(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.stop()
    }
}
