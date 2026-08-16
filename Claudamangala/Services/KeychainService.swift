import Foundation
import Security

/// Every query in this file filters on `service`, so this type structurally
/// cannot read or write any Keychain item other than Claude Code's own
/// "Claude Code-credentials" generic password entry.
enum KeychainService {
    private static let service = "Claude Code-credentials"

    // MARK: - Read

    /// Looks up the existing item, returning both its `kSecAttrAccount`
    /// value (needed to target the SAME item on update — discovered
    /// empirically to be the macOS username, but never assumed, always
    /// re-read here) and its decoded JSON blob.
    static func readCurrentBlob() throws -> (account: String, blob: KeychainCredentialsBlob) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecReturnAttributes: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainServiceError.itemNotFound
        }
        guard status == errSecSuccess, let attributes = result as? [CFString: Any] else {
            throw KeychainServiceError.osStatus(status)
        }
        guard
            let account = attributes[kSecAttrAccount] as? String,
            let data = attributes[kSecValueData] as? Data
        else {
            throw KeychainServiceError.malformedBlob
        }

        let blob = try KeychainCredentialsBlob.decode(from: data)
        return (account, blob)
    }

    /// Convenience for the "Add Account" flow — just the claudeAiOauth
    /// section of whatever session is currently active on this Mac.
    static func readCurrentClaudeCredentials() throws -> ClaudeOAuthCredentials {
        try readCurrentBlob().blob.claudeAiOauth
    }

    // MARK: - Write

    /// Fully replaces the Keychain item's secret with just
    /// `{"claudeAiOauth": {...newCredentials}}` — any other top-level key
    /// that may have been present (e.g. `mcpOAuth`) is intentionally
    /// dropped, not preserved. Falls back to creating a new item only if
    /// none exists yet (first-run-ever case).
    static func writeCredentials(_ newCredentials: ClaudeOAuthCredentials) throws {
        do {
            let (account, _) = try readCurrentBlob()
            let freshBlob = KeychainCredentialsBlob(claudeAiOauth: newCredentials, otherTopLevelKeys: [:])
            let newData = try freshBlob.encode()

            let matchQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            let updateFields: [CFString: Any] = [kSecValueData: newData]

            let status = SecItemUpdate(matchQuery as CFDictionary, updateFields as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainServiceError.osStatus(status)
            }
        } catch KeychainServiceError.itemNotFound {
            try addFreshItem(newCredentials)
        }
    }

    /// First-run-ever fallback: no existing "Claude Code-credentials" item
    /// on this Mac at all. Account attribute confirmed empirically to be the
    /// macOS username (matches how `claude login` itself creates the item).
    private static func addFreshItem(_ credentials: ClaudeOAuthCredentials) throws {
        let blob = KeychainCredentialsBlob(claudeAiOauth: credentials, otherTopLevelKeys: [:])
        let data = try blob.encode()
        let account = NSUserName()

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainServiceError.osStatus(status)
        }
    }
}
