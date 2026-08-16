import Foundation
import Security

enum KeychainService {
    private static let service = "Claude Code-credentials"

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

    static func readCurrentClaudeCredentials() throws -> ClaudeOAuthCredentials {
        try readCurrentBlob().blob.claudeAiOauth
    }

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
