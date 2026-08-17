import Foundation

enum UsagePreferences {
    static let fetchOnMenuOpenKey = "usageFetchOnMenuOpen"

    static var fetchOnMenuOpen: Bool {
        get { UserDefaults.standard.bool(forKey: fetchOnMenuOpenKey) }
        set { UserDefaults.standard.set(newValue, forKey: fetchOnMenuOpenKey) }
    }
}
