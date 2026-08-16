import Foundation
import Observation

@MainActor
@Observable
final class AccountsViewModel {
    var accounts: [ClaudeAccount] = []
    var lastActionError: String?
    var permissionDenied = false

    private var pollTask: Task<Void, Never>?
    private var firestore: FirestoreRESTService?
    private var pipeline: PipelineTriggerService?
    var refreshingAccountIds: Set<String> = []

    func startListening(session: FirebaseSession) {
        firestore = FirestoreRESTService(session: session)
        pipeline = PipelineTriggerService(session: session, firestore: firestore!)
        guard pollTask == nil else { return }

        pollTask = Task {
            while !Task.isCancelled {
                await refreshAccounts()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopListening() {
        pollTask?.cancel()
        pollTask = nil
        firestore = nil
        pipeline = nil
        refreshingAccountIds = []
        accounts = []
        permissionDenied = false
        lastActionError = nil
    }

    private func refreshAccounts() async {
        guard let firestore else { return }
        do {
            accounts = try await firestore.fetchAccounts()
            permissionDenied = false
            lastActionError = nil
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

    func triggerPipelineRefresh(accountId: String?) async throws {
        guard let accountId else { throw PipelineTriggerError.invalidAccount }
        guard let pipeline else { return }

        refreshingAccountIds.insert(accountId)
        defer { refreshingAccountIds.remove(accountId) }

        try await pipeline.triggerRefresh(accountId: accountId)
        await refreshAccounts()
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
