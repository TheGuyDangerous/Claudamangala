import Foundation

enum OAuthConfigLoader {
    static func load(firestore: FirestoreRESTService? = nil) async throws -> OAuthConfig {
        if let bundled = loadFromBundle() {
            return bundled
        }
        if let firestore {
            return try await firestore.fetchOAuthConfig()
        }
        throw OAuthConfigError.missing
    }

    private static func loadFromBundle() -> OAuthConfig? {
        guard let url = Bundle.main.url(forResource: "OAuthConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        guard
            let clientId = plist["clientId"] as? String,
            let tokenEndpointString = plist["tokenEndpoint"] as? String,
            let tokenEndpoint = URL(string: tokenEndpointString),
            !clientId.isEmpty,
            !tokenEndpointString.isEmpty
        else { return nil }

        return OAuthConfig(clientId: clientId, tokenEndpoint: tokenEndpoint)
    }
}
