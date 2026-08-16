import Foundation

struct ClaudeOAuthCredentials: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var scopes: [String]
    var refreshTokenExpiresAt: Double?
    var subscriptionType: String?
    var rateLimitTier: String?
}

struct KeychainCredentialsBlob {
    var claudeAiOauth: ClaudeOAuthCredentials
    var otherTopLevelKeys: [String: Any]

    static func decode(from data: Data) throws -> KeychainCredentialsBlob {
        guard
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw KeychainServiceError.malformedBlob
        }
        guard let oauthDict = raw["claudeAiOauth"] else {
            throw KeychainServiceError.missingClaudeAiOauth
        }
        let oauthData = try JSONSerialization.data(withJSONObject: oauthDict)
        let oauth = try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: oauthData)

        var others = raw
        others.removeValue(forKey: "claudeAiOauth")
        return KeychainCredentialsBlob(claudeAiOauth: oauth, otherTopLevelKeys: others)
    }

    func encode() throws -> Data {
        let oauthData = try JSONEncoder().encode(claudeAiOauth)
        guard
            let oauthDict = try JSONSerialization.jsonObject(with: oauthData) as? [String: Any]
        else {
            throw KeychainServiceError.malformedBlob
        }
        var merged = otherTopLevelKeys
        merged["claudeAiOauth"] = oauthDict
        return try JSONSerialization.data(withJSONObject: merged, options: [.sortedKeys])
    }
}

enum KeychainServiceError: Error, LocalizedError {
    case itemNotFound
    case malformedBlob
    case missingClaudeAiOauth
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No Claude Code session found in Keychain — run `claude login` first."
        case .malformedBlob:
            return "Existing Keychain item isn't valid JSON — can't safely merge into it."
        case .missingClaudeAiOauth:
            return "Existing Keychain item has no claudeAiOauth section."
        case .osStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "\(message) (status \(status))"
        }
    }
}
