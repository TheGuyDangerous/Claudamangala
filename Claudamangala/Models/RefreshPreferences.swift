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
    private static let cloudRefreshAllowlistedEmails: Set<String> = [
        "owner@example.com",
    ]

    static func canUseCloudRefresh(email: String?) -> Bool {
        guard let email else { return false }
        return cloudRefreshAllowlistedEmails.contains(email.lowercased())
    }

    static func oauthRefreshMode(for email: String?) -> OAuthRefreshMode {
        let stored = oauthRefreshMode
        if stored == .cloud, !canUseCloudRefresh(email: email) {
            return .local
        }
        return stored
    }

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
