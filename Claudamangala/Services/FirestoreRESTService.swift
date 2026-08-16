import Foundation

struct AccountRefreshSnapshot: Equatable {
    let lastRefreshStatus: String
    let expiresAt: Double
    let lastRefreshedAtRaw: String?
    let updatedAtRaw: String?
}

struct FirestoreRESTService {
    let session: FirebaseSession

    private var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents"
    }

    func fetchAccounts() async throws -> [ClaudeAccount] {
        let url = URL(string: "\(baseURL)/claude_accounts")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let documents = json?["documents"] as? [[String: Any]] ?? []
        return documents.compactMap(parseAccount).sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    func fetchAccount(id: String) async throws -> ClaudeAccount {
        let url = URL(string: "\(baseURL)/claude_accounts/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let account = parseAccount(from: json ?? [:]) else {
            throw FirestoreRESTError.http(500)
        }
        return account
    }

    /// Lightweight snapshot for fast refresh-completion polling (raw timestamp strings
    /// so we don't depend on Date parsing).
    func fetchRefreshSnapshot(accountId: String) async throws -> AccountRefreshSnapshot {
        let url = URL(string: "\(baseURL)/claude_accounts/\(accountId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fields = json?["fields"] as? [String: Any],
              let lastRefreshStatus = FirestoreValue.stringValue(fields["lastRefreshStatus"]),
              let expiresAt = FirestoreValue.numberValue(fields["expiresAt"])
        else {
            throw FirestoreRESTError.http(500)
        }

        return AccountRefreshSnapshot(
            lastRefreshStatus: lastRefreshStatus,
            expiresAt: expiresAt,
            lastRefreshedAtRaw: FirestoreValue.timestampRawValue(fields["lastRefreshedAt"]),
            updatedAtRaw: FirestoreValue.timestampRawValue(fields["updatedAt"])
        )
    }

    func fetchPipelineConfig() async throws -> PipelineConfig {
        let url = URL(string: "\(baseURL)/app_config/pipeline")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirestoreRESTError.network }
        if http.statusCode == 404 { throw PipelineTriggerError.configMissing }
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fields = json?["fields"] as? [String: Any] else {
            throw PipelineTriggerError.configMissing
        }

        guard
            let githubOwner = FirestoreValue.stringValue(fields["githubOwner"]),
            let githubRepo = FirestoreValue.stringValue(fields["githubRepo"]),
            let workflowFile = FirestoreValue.stringValue(fields["workflowFile"]),
            let defaultBranch = FirestoreValue.stringValue(fields["defaultBranch"]),
            let dispatchToken = FirestoreValue.stringValue(fields["dispatchToken"]),
            let dispatchSecret = FirestoreValue.stringValue(fields["dispatchSecret"])
        else {
            throw PipelineTriggerError.configMissing
        }

        return PipelineConfig(
            githubOwner: githubOwner,
            githubRepo: githubRepo,
            workflowFile: workflowFile,
            defaultBranch: defaultBranch,
            dispatchToken: dispatchToken,
            dispatchSecret: dispatchSecret
        )
    }

    func documentExists(id: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/claude_accounts/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirestoreRESTError.network }
        if http.statusCode == 404 { return false }
        if http.statusCode == 200 { return true }
        throw FirestoreRESTError.http(http.statusCode)
    }

    func updateLabel(accountId: String, newLabel: String) async throws {
        let now = FirestoreValue.timestamp()
        let body: [String: Any] = [
            "fields": [
                "label": FirestoreValue.string(newLabel),
                "updatedAt": now,
            ],
        ]
        try await patch(
            path: "claude_accounts/\(accountId)",
            body: body,
            fieldPaths: ["label", "updatedAt"]
        )
    }

    func createAccount(
        docId: String,
        label: String,
        credentials: ClaudeOAuthCredentials
    ) async throws {
        let now = FirestoreValue.timestamp()
        let body: [String: Any] = [
            "fields": [
                "label": FirestoreValue.string(label),
                "accessToken": FirestoreValue.string(credentials.accessToken),
                "refreshToken": FirestoreValue.string(credentials.refreshToken),
                "expiresAt": FirestoreValue.number(credentials.expiresAt),
                "scopes": FirestoreValue.stringArray(credentials.scopes),
                "active": FirestoreValue.bool(true),
                "lastRefreshStatus": FirestoreValue.string("never"),
                "lastError": FirestoreValue.null(),
                "consecutiveFailures": FirestoreValue.integer(0),
                "lastRefreshedAt": FirestoreValue.null(),
                "createdAt": now,
                "updatedAt": now,
            ],
        ]

        let url = URL(string: "\(baseURL)/claude_accounts?documentId=\(docId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)
    }

    // MARK: - Private

    private func patch(path: String, body: [String: Any], fieldPaths: [String]) async throws {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        components.queryItems = fieldPaths.map { URLQueryItem(name: "updateMask.fieldPaths", value: $0) }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)
    }

    private func parseAccount(from document: [String: Any]) -> ClaudeAccount? {
        guard
            let name = document["name"] as? String,
            let fields = document["fields"] as? [String: Any]
        else { return nil }

        let id = name.split(separator: "/").last.map(String.init)
        guard
            let label = FirestoreValue.stringValue(fields["label"]),
            let accessToken = FirestoreValue.stringValue(fields["accessToken"]),
            let refreshToken = FirestoreValue.stringValue(fields["refreshToken"]),
            let expiresAt = FirestoreValue.numberValue(fields["expiresAt"]),
            let scopes = FirestoreValue.stringArrayValue(fields["scopes"]),
            let active = FirestoreValue.boolValue(fields["active"]),
            let lastRefreshStatus = FirestoreValue.stringValue(fields["lastRefreshStatus"])
        else { return nil }

        return ClaudeAccount(
            id: id,
            label: label,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            scopes: scopes,
            active: active,
            lastRefreshStatus: lastRefreshStatus,
            lastError: FirestoreValue.stringValue(fields["lastError"]),
            consecutiveFailures: Int(FirestoreValue.numberValue(fields["consecutiveFailures"]) ?? 0),
            lastRefreshedAt: FirestoreValue.dateValue(fields["lastRefreshedAt"]),
            createdAt: FirestoreValue.dateValue(fields["createdAt"]),
            updatedAt: FirestoreValue.dateValue(fields["updatedAt"])
        )
    }

    private func throwIfHTTPError(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw FirestoreRESTError.network
        }
        guard (200 ... 299).contains(http.statusCode) else {
            if http.statusCode == 403 {
                throw FirestoreRESTError.permissionDenied
            }
            throw FirestoreRESTError.http(http.statusCode)
        }
    }
}

enum FirestoreRESTError: LocalizedError {
    case network
    case http(Int)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .network:
            return "No internet connection."
        case .permissionDenied:
            return "Access denied — check Firebase Auth configuration."
        case .http(let code):
            return "Firestore request failed (HTTP \(code))."
        }
    }
}

private enum FirestoreValue {
    static func string(_ value: String) -> [String: Any] { ["stringValue": value] }
    static func bool(_ value: Bool) -> [String: Any] { ["booleanValue": value] }
    static func integer(_ value: Int) -> [String: Any] { ["integerValue": "\(value)"] }
    static func number(_ value: Double) -> [String: Any] {
        if value.rounded() == value {
            return ["integerValue": String(Int(value))]
        }
        return ["doubleValue": String(value)]
    }
    static func null() -> [String: Any] { ["nullValue": NSNull()] }
    static func stringArray(_ values: [String]) -> [String: Any] {
        ["arrayValue": ["values": values.map { string($0) }]]
    }
    static func timestamp(_ date: Date = Date()) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ["timestampValue": formatter.string(from: date)]
    }

    static func stringValue(_ field: Any?) -> String? {
        (field as? [String: Any])?["stringValue"] as? String
    }

    static func boolValue(_ field: Any?) -> Bool? {
        (field as? [String: Any])?["booleanValue"] as? Bool
    }

    static func numberValue(_ field: Any?) -> Double? {
        guard let dict = field as? [String: Any] else { return nil }
        if let intString = dict["integerValue"] as? String { return Double(intString) }
        if let doubleString = dict["doubleValue"] as? String { return Double(doubleString) }
        return nil
    }

    static func stringArrayValue(_ field: Any?) -> [String]? {
        guard
            let dict = field as? [String: Any],
            let array = dict["arrayValue"] as? [String: Any],
            let values = array["values"] as? [[String: Any]]
        else { return nil }
        return values.compactMap { $0["stringValue"] as? String }
    }

    static func dateValue(_ field: Any?) -> Date? {
        guard let timestamp = timestampRawValue(field) else { return nil }
        return parseFirestoreTimestamp(timestamp)
    }

    static func timestampRawValue(_ field: Any?) -> String? {
        (field as? [String: Any])?["timestampValue"] as? String
    }

    /// Firestore REST returns RFC3339 timestamps with 3–9 fractional digits;
    /// `ISO8601DateFormatter` only accepts up to 3.
    static func parseFirestoreTimestamp(_ timestamp: String) -> Date? {
        let normalized = normalizeFractionalSeconds(timestamp)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: normalized) { return date }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: normalized)
    }

    private static func normalizeFractionalSeconds(_ timestamp: String) -> String {
        guard let dot = timestamp.firstIndex(of: ".") else { return timestamp }
        guard let z = timestamp.firstIndex(of: "Z") else { return timestamp }
        let fraction = timestamp[timestamp.index(after: dot)..<z]
        guard fraction.count > 3 else { return timestamp }
        return String(timestamp[..<dot]) + "." + fraction.prefix(3) + "Z"
    }
}
