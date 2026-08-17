import Foundation

enum OAuthRefreshMode: String, CaseIterable {
    case local
    case cloud

    var title: String {
        switch self {
        case .local:
            return "Local refresh"
        case .cloud:
            return "Cloud refresh"
        }
    }
}

enum RefreshPreferences {
    static let oauthRefreshModeKey = "oauthRefreshMode"

    static var oauthRefreshMode: OAuthRefreshMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: oauthRefreshModeKey),
                  let mode = OAuthRefreshMode(rawValue: raw)
            else {
                return .local
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: oauthRefreshModeKey)
        }
    }
}
