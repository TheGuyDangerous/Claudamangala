import Foundation
import ServiceManagement

enum LaunchPreferences {
    static let launchAtLoginKey = "launchAtLogin"

    static var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: launchAtLoginKey) }
        set { UserDefaults.standard.set(newValue, forKey: launchAtLoginKey) }
    }

    static var isRegisteredWithSystem: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func syncPreferenceWithSystem() {
        launchAtLogin = isRegisteredWithSystem
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        launchAtLogin = enabled
    }

    static func applyStoredPreferenceIfNeeded() {
        let desired = launchAtLogin
        let actual = isRegisteredWithSystem
        guard desired != actual else { return }

        do {
            try setLaunchAtLogin(desired)
        } catch {
            launchAtLogin = actual
        }
    }
}
