import Foundation
import Observation

@MainActor
@Observable
final class AccountsViewModel {
    var accounts: [ClaudeAccount] = []
    var lastActionError: String?
    var permissionDenied = false
    var isLoadingAccounts = false

    var canUseCloudRefresh = false

    private var firestore: FirestoreRESTService?
    private var pipeline: PipelineTriggerService?
    var refreshingAccountIds: Set<String> = []
    var refreshingUsageAccountIds: Set<String> = []
    var usageByAccountId: [String: ClaudeAccountUsage] = [:]

    private var usageRefreshTask: Task<Void, Never>?
    private var menuFetchTask: Task<Void, Never>?
    private var menuIsOpen = false

    func startListening(session: FirebaseSession) {
        firestore = FirestoreRESTService(session: session, ownerUid: session.userId)
        pipeline = PipelineTriggerService(session: session, firestore: firestore!)
        Task { await refreshCloudRefreshAccess() }
        if menuIsOpen {
            scheduleMenuFetch()
        }
    }

    func stopListening() {
        menuFetchTask?.cancel()
        menuFetchTask = nil
        usageRefreshTask?.cancel()
        usageRefreshTask = nil
        canUseCloudRefresh = false
        firestore = nil
        pipeline = nil
        refreshingAccountIds = []
        refreshingUsageAccountIds = []
        accounts = []
        usageByAccountId = [:]
        permissionDenied = false
        lastActionError = nil
        isLoadingAccounts = false
        menuIsOpen = false
    }

    func refreshAccounts() async {
        guard let firestore else { return }
        isLoadingAccounts = true
        defer { isLoadingAccounts = false }

        do {
            let fetched = try await firestore.fetchAccounts()
            accounts = fetched.accounts
            permissionDenied = false
            if fetched.accounts.isEmpty, fetched.skippedDocumentCount > 0 {
                lastActionError = "Found Firebase accounts but could not read them — check document fields."
            } else {
                lastActionError = nil
            }
            if menuIsOpen {
                hydrateUsageFromAccounts()
            }
        } catch let error as FirestoreRESTError {
            if case .permissionDenied = error {
                permissionDenied = true
            } else {
                lastActionError = error.errorDescription
            }
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    func rename(accountId: String, newLabel: String) async {
        guard let firestore else { return }
        do {
            try await firestore.updateLabel(accountId: accountId, newLabel: newLabel)
            await refreshAccounts()
        } catch {
            lastActionError = error.localizedDescription
        }
    }

    func addAccount(docId: String, label: String, credentials: ClaudeOAuthCredentials) async throws {
        guard let firestore else { return }

        if try await firestore.documentExists(id: docId) {
            throw AddAccountError.duplicateId
        }

        try await firestore.createAccount(docId: docId, label: label, credentials: credentials)
        await refreshAccounts()
    }

    func triggerRefresh(accountId: String?) async throws {
        switch RefreshPreferences.oauthRefreshMode(canUseCloudRefresh: canUseCloudRefresh) {
        case .cloud:
            try await triggerPipelineRefresh(accountId: accountId)
        case .local:
            try await triggerLocalRefresh(accountId: accountId)
        }
    }

    func triggerPipelineRefresh(accountId: String?) async throws {
        guard let accountId else { throw PipelineTriggerError.invalidAccount }
        guard let pipeline else { return }

        refreshingAccountIds.insert(accountId)
        defer { refreshingAccountIds.remove(accountId) }

        try await pipeline.triggerRefresh(accountId: accountId)
        await refreshAccounts()
    }

    func triggerLocalRefresh(accountId: String?) async throws {
        guard let accountId else { throw PipelineTriggerError.invalidAccount }
        guard let firestore else { return }

        refreshingAccountIds.insert(accountId)
        defer { refreshingAccountIds.remove(accountId) }

        let account = try await firestore.fetchAccount(id: accountId)
        let oauthConfig = try await OAuthConfigLoader.load(firestore: firestore)

        do {
            let result = try await ClaudeOAuthRefreshService.refresh(
                refreshToken: account.refreshToken,
                config: oauthConfig
            )
            try await firestore.updateOAuthRefreshSuccess(
                accountId: accountId,
                accessToken: result.accessToken,
                refreshToken: result.refreshToken,
                expiresAt: result.expiresAt
            )
            await refreshAccounts()
        } catch {
            let failures = account.consecutiveFailures + 1
            let message = error.localizedDescription
            try? await firestore.updateOAuthRefreshFailure(
                accountId: accountId,
                error: message,
                consecutiveFailures: failures
            )
            await refreshAccounts()
            throw error
        }
    }

    func refreshAllAccountsLocally() async {
        guard firestore != nil else { return }

        if accounts.isEmpty {
            await refreshAccounts()
        }

        for account in accounts {
            if Task.isCancelled { return }
            guard let accountId = account.id else { continue }
            guard !refreshingAccountIds.contains(accountId) else { continue }

            do {
                try await triggerLocalRefresh(accountId: accountId)
            } catch {
                continue
            }
        }
    }

    func isRefreshing(accountId: String?) -> Bool {
        guard let accountId else { return false }
        return refreshingAccountIds.contains(accountId)
    }

    func applyAccount(_ account: ClaudeAccount) throws {
        let credentials = ClaudeOAuthCredentials(
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            expiresAt: account.expiresAt,
            scopes: account.scopes,
            refreshTokenExpiresAt: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )
        try KeychainService.writeCredentials(credentials)
    }

    func usage(for account: ClaudeAccount) -> ClaudeAccountUsage {
        guard let id = account.id else { return ClaudeAccountUsage() }
        if let cached = usageByAccountId[id] { return cached }
        return ClaudeAccountUsage.fromStored(account: account)
    }

    func isRefreshingUsage(accountId: String?) -> Bool {
        guard let accountId else { return false }
        return refreshingUsageAccountIds.contains(accountId)
    }

    func menuDidOpen() {
        menuIsOpen = true
        scheduleMenuFetch()
    }

    func menuDidClose() {
        menuIsOpen = false
        usageRefreshTask?.cancel()
        usageRefreshTask = nil
        usageByAccountId = [:]
        refreshingUsageAccountIds = []
    }

    private func scheduleMenuFetch() {
        menuFetchTask?.cancel()
        menuFetchTask = Task {
            guard firestore != nil else {
                lastActionError = "Firebase is not connected yet — try again in a moment."
                return
            }

            await refreshAccounts()
            if Task.isCancelled { return }
            hydrateUsageFromAccounts()
            if UsagePreferences.fetchOnMenuOpen {
                refreshUsageFromAPIForAllAccounts()
            }
        }
    }

    func refreshUsage(for account: ClaudeAccount) {
        guard let id = account.id, let firestore else { return }
        usageRefreshTask?.cancel()

        Task {
            refreshingUsageAccountIds.insert(id)
            defer { refreshingUsageAccountIds.remove(id) }

            let fallback = usage(for: account)
            usageByAccountId[id] = .loading

            do {
                let usage = try await ClaudeUsageService.fetch(accessToken: account.accessToken)
                try await firestore.updateUsageSnapshot(
                    accountId: id,
                    fiveHourAvailable: usage.fiveHourAvailable,
                    weeklyAvailable: usage.weeklyAvailable
                )
                usageByAccountId[id] = usage
                await refreshAccounts()
            } catch {
                if fallback.hasData {
                    usageByAccountId[id] = fallback
                } else {
                    usageByAccountId[id] = ClaudeAccountUsage(
                        fiveHourAvailable: account.fiveHourAvailable,
                        weeklyAvailable: account.weeklyAvailable,
                        hasError: true,
                        isStored: account.hasStoredUsage
                    )
                }
            }
        }
    }

    private func refreshUsageFromAPIForAllAccounts() {
        usageRefreshTask?.cancel()
        let snapshot = accounts
        guard !snapshot.isEmpty else { return }

        usageRefreshTask = Task {
            for account in snapshot {
                if Task.isCancelled { return }
                guard let id = account.id else { continue }
                refreshingUsageAccountIds.insert(id)
                let fallback = usage(for: account)
                usageByAccountId[id] = .loading

                do {
                    let usage = try await ClaudeUsageService.fetch(accessToken: account.accessToken)
                    try await firestore?.updateUsageSnapshot(
                        accountId: id,
                        fiveHourAvailable: usage.fiveHourAvailable,
                        weeklyAvailable: usage.weeklyAvailable
                    )
                    usageByAccountId[id] = usage
                } catch {
                    usageByAccountId[id] = fallback.hasData ? fallback : ClaudeAccountUsage.fromStored(account: account)
                }

                refreshingUsageAccountIds.remove(id)
            }
            await refreshAccounts()
        }
    }

    private func hydrateUsageFromAccounts() {
        for account in accounts {
            guard let id = account.id else { continue }
            if refreshingUsageAccountIds.contains(id) { continue }
            if usageByAccountId[id]?.isLoading == true { continue }
            usageByAccountId[id] = ClaudeAccountUsage.fromStored(account: account)
        }
    }

    func refreshCloudRefreshAccess() async {
        guard let firestore else {
            canUseCloudRefresh = false
            return
        }
        canUseCloudRefresh = await firestore.checkCloudRefreshAccess()
    }
}

enum AddAccountError: Error, LocalizedError {
    case duplicateId

    var errorDescription: String? {
        switch self {
        case .duplicateId:
            return "An account with this ID already exists — choose a different ID."
        }
    }
}
