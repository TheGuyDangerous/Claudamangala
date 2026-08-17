import Foundation
import Security

enum KeychainService {
    private static let service = "Claude Code-credentials"
    private static let accountNameDefaultsKey = "com.sannidhya.claude.keychainAccountName"

    private struct CachedEntry {
        let account: String
        let blob: KeychainCredentialsBlob
    }

    private static var cachedEntry: CachedEntry?
    private static var fetchInFlight = false
    private static let lock = NSLock()

    static func readCurrentBlob() throws -> (account: String, blob: KeychainCredentialsBlob) {
        if let cached = cachedSnapshot() {
            return (cached.account, cached.blob)
        }

        return try synchronizedFetch()
    }

    static func readCurrentClaudeCredentials() throws -> ClaudeOAuthCredentials {
        try readCurrentBlob().blob.claudeAiOauth
    }

    static func writeCredentials(_ newCredentials: ClaudeOAuthCredentials) throws {
        let account = try resolvedAccountNameForWrite()
        let freshBlob = KeychainCredentialsBlob(claudeAiOauth: newCredentials, otherTopLevelKeys: [:])
        let newData = try freshBlob.encode()

        let matchQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let updateFields: [CFString: Any] = [kSecValueData: newData]

        var status = SecItemUpdate(matchQuery as CFDictionary, updateFields as CFDictionary)
        if status == errSecItemNotFound {
            try addFreshItem(newCredentials, account: account)
            status = errSecSuccess
        }
        guard status == errSecSuccess else {
            throw KeychainServiceError.osStatus(status)
        }

        storeCache(account: account, blob: freshBlob)
    }

    static func clearCache() {
        lock.lock()
        cachedEntry = nil
        fetchInFlight = false
        lock.unlock()
    }

    // MARK: - Private

    private static func cachedSnapshot() -> CachedEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cachedEntry
    }

    private static func storeCache(account: String, blob: KeychainCredentialsBlob) {
        lock.lock()
        cachedEntry = CachedEntry(account: account, blob: blob)
        lock.unlock()
        UserDefaults.standard.set(account, forKey: accountNameDefaultsKey)
    }

    private static func resolvedAccountNameForWrite() throws -> String {
        if let cached = cachedSnapshot() {
            return cached.account
        }
        if let stored = UserDefaults.standard.string(forKey: accountNameDefaultsKey), !stored.isEmpty {
            return stored
        }
        return try readCurrentBlob().account
    }

    private static func synchronizedFetch() throws -> (account: String, blob: KeychainCredentialsBlob) {
        lock.lock()
        if let cached = cachedEntry {
            lock.unlock()
            return (cached.account, cached.blob)
        }

        while fetchInFlight {
            lock.unlock()
            Thread.sleep(forTimeInterval: 0.05)
            lock.lock()
            if let cached = cachedEntry {
                lock.unlock()
                return (cached.account, cached.blob)
            }
        }

        fetchInFlight = true
        lock.unlock()

        defer {
            lock.lock()
            fetchInFlight = false
            lock.unlock()
        }

        do {
            let result = try fetchBlobFromKeychain()
            storeCache(account: result.account, blob: result.blob)
            return result
        } catch {
            throw error
        }
    }

    private static func fetchBlobFromKeychain() throws -> (account: String, blob: KeychainCredentialsBlob) {
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

    private static func addFreshItem(_ credentials: ClaudeOAuthCredentials, account: String) throws {
        let blob = KeychainCredentialsBlob(claudeAiOauth: credentials, otherTopLevelKeys: [:])
        let data = try blob.encode()

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
