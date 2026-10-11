import Foundation
import ServiceManagement

@MainActor
final class Preferences: ObservableObject {
    @Published var launchAtLogin = false
    @Published var loginMessage = ""

    /// Copy only our prototype's setup/placement keys, never overwrite new choices.
    /// Login-item registration belongs to the bundle identity and is not migrated.
    static func migratePrototypeSettings(
        from legacy: UserDefaults? = UserDefaults(suiteName: "local.tidybar.app"),
        to current: UserDefaults = .standard
    ) {
        guard let legacy, !current.bool(forKey: "didMigratePrototype") else { return }
        for key in ["hasShownSetup", "NSStatusItem Preferred Position TidyBar.Toggle",
                    "NSStatusItem Visible TidyBar.Toggle"] {
            if current.object(forKey: key) == nil, let value = legacy.object(forKey: key) {
                current.set(value, forKey: key)
            }
        }
        current.set(true, forKey: "didMigratePrototype")
    }

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginMessage = status == .requiresApproval
            ? L10n.loginApproval : ""
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
        } catch {
            refreshLoginStatus()
            loginMessage = String(format: L10n.loginFailed, error.localizedDescription)
        }
    }
}
