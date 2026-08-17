import Foundation
import Security

enum KeychainService {
    private static let service = "Claude Code-credentials"
    private static let accountNameDefaultsKey = "com.sannidhya.claude.keychainAccountName"

    private struct CachedEntry {
        let account: String
        let blob: KeychainCredentialsBlob
    }

    private static let cacheLock = NSLock()
    private static var cachedEntry: CachedEntry?
    private static var inFlightRead: Task<(account: String, blob: KeychainCredentialsBlob), Error>?

    // MARK: - Public (async — always prefer these)

    static func readCurrentClaudeCredentials() async throws -> ClaudeOAuthCredentials {
        try await readCurrentBlob().blob.claudeAiOauth
    }

    static func readCurrentBlob() async throws -> (account: String, blob: KeychainCredentialsBlob) {
        if let cached = cachedSnapshot() {
            return (cached.account, cached.blob)
        }

        if let inFlightRead {
            return try await inFlightRead.value
        }

        let task = Task<(account: String, blob: KeychainCredentialsBlob), Error> {
            try await KeychainAccessGate.whileAccessing {
                try await performKeychainReadOffMainThread()
            }
        }

        cacheLock.lock()
        inFlightRead = task
        cacheLock.unlock()

        defer {
            cacheLock.lock()
            inFlightRead = nil
            cacheLock.unlock()
        }

        let result = try await task.value
        storeCache(account: result.account, blob: result.blob)
        return result
    }

    static func writeCredentials(_ newCredentials: ClaudeOAuthCredentials) async throws {
        try await KeychainAccessGate.whileAccessing {
            try await performKeychainWriteOffMainThread(newCredentials)
        }
    }

    static func clearCache() {
        cacheLock.lock()
        cachedEntry = nil
        inFlightRead?.cancel()
        inFlightRead = nil
        cacheLock.unlock()
    }

    // MARK: - Private

    private static func cachedSnapshot() -> CachedEntry? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedEntry
    }

    private static func storeCache(account: String, blob: KeychainCredentialsBlob) {
        cacheLock.lock()
        cachedEntry = CachedEntry(account: account, blob: blob)
        cacheLock.unlock()
        UserDefaults.standard.set(account, forKey: accountNameDefaultsKey)
    }

    private static func performKeychainReadOffMainThread() async throws -> (account: String, blob: KeychainCredentialsBlob) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try fetchBlobFromKeychain())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func performKeychainWriteOffMainThread(_ newCredentials: ClaudeOAuthCredentials) async throws {
        let account: String
        if let cached = cachedSnapshot() {
            account = cached.account
        } else if let stored = UserDefaults.standard.string(forKey: accountNameDefaultsKey), !stored.isEmpty {
            account = stored
        } else {
            let discovered = try await performKeychainReadOffMainThread()
            storeCache(account: discovered.account, blob: discovered.blob)
            account = discovered.account
        }

        let freshBlob = KeychainCredentialsBlob(claudeAiOauth: newCredentials, otherTopLevelKeys: [:])
        let newData = try freshBlob.encode()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
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
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        storeCache(account: account, blob: freshBlob)
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
