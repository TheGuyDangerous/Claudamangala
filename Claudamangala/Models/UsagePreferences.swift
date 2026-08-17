import Foundation

enum UsagePreferences {
    static let fetchOnMenuOpenKey = "usageFetchOnMenuOpen"
    static let menuBarPinnedAccountIdKey = "menuBarPinnedAccountId"

    static var fetchOnMenuOpen: Bool {
        get { UserDefaults.standard.bool(forKey: fetchOnMenuOpenKey) }
        set { UserDefaults.standard.set(newValue, forKey: fetchOnMenuOpenKey) }
    }

    static var menuBarPinnedAccountId: String? {
        get {
            let value = UserDefaults.standard.string(forKey: menuBarPinnedAccountIdKey) ?? ""
            return value.isEmpty ? nil : value
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: menuBarPinnedAccountIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: menuBarPinnedAccountIdKey)
            }
        }
    }
}
