import Foundation

struct ClaudeOAuthCredentials: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var scopes: [String]
    var refreshTokenExpiresAt: Double?
    var subscriptionType: String?
    var rateLimitTier: String?

    /// Parses credentials exported from Claude Code (`claudeAiOauth` wrapper) or a bare oauth object.
    static func parse(importedJSON text: String) throws -> ClaudeOAuthCredentials {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClaudeOAuthCredentialsParseError.empty
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw ClaudeOAuthCredentialsParseError.invalidEncoding
        }

        if let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauthDict = raw["claudeAiOauth"]
        {
            let oauthData = try JSONSerialization.data(withJSONObject: oauthDict)
            return try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: oauthData)
        }

        return try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: data)
    }
}

enum ClaudeOAuthCredentialsParseError: Error, LocalizedError {
    case empty
    case invalidEncoding
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Paste the JSON credentials first."
        case .invalidEncoding:
            return "Could not read the pasted text."
        case .invalidFormat:
            return "JSON must include claudeAiOauth (or accessToken, refreshToken, expiresAt, scopes)."
        }
    }
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
