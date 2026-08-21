import Foundation

enum ApplyDestination: String, CaseIterable {
    case keychain
    case credentialsFile

    var title: String {
        switch self {
        case .keychain:
            return "Keychain"
        case .credentialsFile:
            return ".claude folder"
        }
    }
}

enum ApplyDestinationPreferences {
    static let destinationKey = "applyDestination"

    static var destination: ApplyDestination {
        get {
            guard
                let raw = UserDefaults.standard.string(forKey: destinationKey),
                let value = ApplyDestination(rawValue: raw)
            else {
                return .keychain
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: destinationKey)
        }
    }
}
