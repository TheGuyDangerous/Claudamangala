import Foundation

enum UpdatePreferences {
    static let checkAutomaticallyKey = "checkForUpdatesAutomatically"
    static let installAutomaticallyKey = "installUpdatesAutomatically"

    static var checkAutomatically: Bool {
        get {
            guard UserDefaults.standard.object(forKey: checkAutomaticallyKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: checkAutomaticallyKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: checkAutomaticallyKey) }
    }

    static var installAutomatically: Bool {
        get {
            guard UserDefaults.standard.object(forKey: installAutomaticallyKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: installAutomaticallyKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: installAutomaticallyKey) }
    }
}
