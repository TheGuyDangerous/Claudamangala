import Foundation

struct PipelineConfig: Decodable {
    let githubOwner: String
    let githubRepo: String
    let workflowFile: String
    let defaultBranch: String
    let dispatchToken: String
    let dispatchSecret: String
}

enum PipelineTriggerError: LocalizedError {
    case configMissing
    case invalidAccount
    case dispatchFailed(String)
    case timedOut
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .configMissing:
            return "Pipeline config missing — add PipelineConfig.plist to the app bundle."
        case .invalidAccount:
            return "This account has no document id."
        case .dispatchFailed(let detail):
            return "Could not start refresh (\(detail))."
        case .timedOut:
            return "Refresh is taking longer than expected — check GitHub Actions."
        case .refreshFailed(let detail):
            return "Refresh failed (\(detail))."
        }
    }
}

struct PipelineTriggerService {
    let session: FirebaseSession
    let firestore: FirestoreRESTService

    func triggerRefresh(accountId: String) async throws {
        let config = try await PipelineConfigLoader.load(firestore: firestore)
        let baseline = try await firestore.fetchRefreshSnapshot(accountId: accountId)

        try await dispatchWorkflow(config: config, accountId: accountId)
        try await waitForFirestoreRefresh(accountId: accountId, baseline: baseline)
    }

    // MARK: - GitHub dispatch

    private func dispatchWorkflow(config: PipelineConfig, accountId: String) async throws {
        let encodedWorkflow = config.workflowFile.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? config.workflowFile
        let url = URL(string: "https://api.github.com/repos/\(config.githubOwner)/\(config.githubRepo)/actions/workflows/\(encodedWorkflow)/dispatches")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.dispatchToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Claudamangala/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "ref": config.defaultBranch,
            "inputs": [
                "account_id": accountId,
                "dispatch_secret": config.dispatchSecret,
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PipelineTriggerError.dispatchFailed("no response")
        }
        guard http.statusCode == 204 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? "HTTP \(http.statusCode)"
            throw PipelineTriggerError.dispatchFailed(detail)
        }
    }

    // MARK: - Firestore polling (fast path)

    private func waitForFirestoreRefresh(
        accountId: String,
        baseline: AccountRefreshSnapshot
    ) async throws {
        let deadline = Date().addingTimeInterval(90)

        while Date() < deadline {
            try await Task.sleep(for: .seconds(1.5))

            let current = try await firestore.fetchRefreshSnapshot(accountId: accountId)
            guard refreshDetected(current: current, baseline: baseline) else { continue }

            switch current.lastRefreshStatus {
            case "success", "skipped":
                return
            case "failed":
                let account = try await firestore.fetchAccount(id: accountId)
                throw PipelineTriggerError.refreshFailed(account.lastError ?? "unknown error")
            default:
                continue
            }
        }

        throw PipelineTriggerError.timedOut
    }

    private func refreshDetected(current: AccountRefreshSnapshot, baseline: AccountRefreshSnapshot) -> Bool {
        current.lastRefreshStatus != baseline.lastRefreshStatus
            || current.expiresAt != baseline.expiresAt
            || current.lastRefreshedAtRaw != baseline.lastRefreshedAtRaw
            || current.updatedAtRaw != baseline.updatedAtRaw
    }
}
