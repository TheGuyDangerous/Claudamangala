import Foundation

/// Mirrors the FULL shape of the macOS Keychain item Claude Code CLI stores
/// under service "Claude Code-credentials". Empirically confirmed this blob
/// is NOT just `{"claudeAiOauth": {...}}` — it's a superset object that can
/// also carry an unrelated `mcpOAuth` key (e.g. other MCP server sessions
/// like Figma) alongside `claudeAiOauth`, and `claudeAiOauth` itself carries
/// more fields than our Firestore schema tracks (refreshTokenExpiresAt,
/// subscriptionType, rateLimitTier).
///
/// `otherTopLevelKeys` captures whatever else was in the original blob when
/// reading (e.g. `mcpOAuth`) so decoding never fails on it — but
/// `KeychainService.writeCredentials` deliberately does NOT preserve these
/// on write: Apply is a full replace, writing only `{"claudeAiOauth": ...}`.
struct ClaudeOAuthCredentials: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var scopes: [String]

    // Present in the real Keychain blob but not tracked by our Firestore
    // schema. Preserved on merge-write when available; nil when this struct
    // was built fresh from a Firestore account (Apply flow), in which case
    // they're simply omitted from the written JSON rather than fabricated.
    var refreshTokenExpiresAt: Double?
    var subscriptionType: String?
    var rateLimitTier: String?
}

/// Represents the whole Keychain secret blob as a loosely-typed JSON object,
/// so keys this app doesn't understand (like `mcpOAuth`) survive untouched
/// through a read-modify-write cycle.
struct KeychainCredentialsBlob {
    var claudeAiOauth: ClaudeOAuthCredentials
    /// Every other top-level key from the original JSON, preserved verbatim.
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

    /// Re-serializes the blob: `otherTopLevelKeys` untouched, `claudeAiOauth`
    /// replaced with the current value of that property.
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
