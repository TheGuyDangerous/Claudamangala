import Foundation

struct OAuthConfig: Equatable {
    let clientId: String
    let tokenEndpoint: URL
}

enum OAuthConfigError: LocalizedError {
    case missing

    var errorDescription: String? {
        switch self {
        case .missing:
            return "OAuth config missing — add OAuthConfig.plist to the app bundle or app_config/oauth in Firestore."
        }
    }
}
