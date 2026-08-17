import Foundation

struct AccountRefreshSnapshot: Equatable {
    let lastRefreshStatus: String
    let expiresAt: Double
    let lastRefreshedAtRaw: String?
    let updatedAtRaw: String?
}

struct FirestoreAccountsFetchResult {
    let accounts: [ClaudeAccount]
    let skippedDocumentCount: Int
}

struct FirestoreRESTService {
    let session: FirebaseSession
    let ownerUid: String

    init(session: FirebaseSession, ownerUid: String) {
        self.session = session
        self.ownerUid = ownerUid
    }

    private var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents"
    }

    private var accountsCollectionPath: String {
        "users/\(ownerUid)/claude_accounts"
    }

    private func accountPath(_ accountId: String) -> String {
        "\(accountsCollectionPath)/\(accountId)"
    }

    /// Ensures `users/{ownerUid}` exists with `ownerUid` + email (idempotent on every sign-in).
    func ensureUserProfile(email: String) async throws {
        guard !ownerUid.isEmpty else { return }

        let path = "users/\(ownerUid)"
        let url = URL(string: "\(baseURL)/\(path)")!
        var getRequest = URLRequest(url: url)
        getRequest.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: getRequest)
        guard let http = response as? HTTPURLResponse else { throw FirestoreRESTError.network }

        let now = FirestoreValue.timestamp()

        switch http.statusCode {
        case 200:
            try await patch(
                path: path,
                body: ["fields": ["updatedAt": now]],
                fieldPaths: ["updatedAt"]
            )
        case 404:
            let body: [String: Any] = [
                "fields": [
                    "ownerUid": FirestoreValue.string(ownerUid),
                    "email": FirestoreValue.string(email),
                    "createdAt": now,
                    "updatedAt": now,
                ],
            ]
            let createURL = URL(string: "\(baseURL)/users?documentId=\(ownerUid)")!
            var createRequest = URLRequest(url: createURL)
            createRequest.httpMethod = "POST"
            createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            createRequest.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")
            createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, createResponse) = try await URLSession.shared.data(for: createRequest)
            try throwIfHTTPError(data: data, response: createResponse)
        default:
            break
        }
    }

    func fetchAccounts() async throws -> FirestoreAccountsFetchResult {
        let url = URL(string: "\(baseURL)/\(accountsCollectionPath)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 403 {
            // Firestore returns 403 when the user can read zero documents in the collection.
            // Normal for a new user who has not added any accounts yet.
            return FirestoreAccountsFetchResult(accounts: [], skippedDocumentCount: 0)
        }
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let documents = json?["documents"] as? [[String: Any]] ?? []
        let accounts = documents.compactMap(parseAccount).sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
        return FirestoreAccountsFetchResult(
            accounts: accounts,
            skippedDocumentCount: max(0, documents.count - accounts.count)
        )
    }

    func fetchAccount(id: String) async throws -> ClaudeAccount {
        let url = URL(string: "\(baseURL)/\(accountPath(id))")!
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

    func fetchRefreshSnapshot(accountId: String) async throws -> AccountRefreshSnapshot {
        let url = URL(string: "\(baseURL)/\(accountPath(accountId))")!
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

    func fetchOAuthConfig() async throws -> OAuthConfig {
        let url = URL(string: "\(baseURL)/app_config/oauth")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirestoreRESTError.network }
        if http.statusCode == 404 { throw OAuthConfigError.missing }
        try throwIfHTTPError(data: data, response: response)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fields = json?["fields"] as? [String: Any] else {
            throw OAuthConfigError.missing
        }

        guard
            let clientId = FirestoreValue.stringValue(fields["clientId"]),
            let tokenEndpointString = FirestoreValue.stringValue(fields["tokenEndpoint"]),
            let tokenEndpoint = URL(string: tokenEndpointString)
        else {
            throw OAuthConfigError.missing
        }

        return OAuthConfig(clientId: clientId, tokenEndpoint: tokenEndpoint)
    }

    func checkCloudRefreshAccess() async -> Bool {
        let url = URL(string: "\(baseURL)/app_config/pipeline")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }

            switch http.statusCode {
            case 200, 404:
                return true
            case 403:
                return false
            default:
                return false
            }
        } catch {
            return false
        }
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
        let url = URL(string: "\(baseURL)/\(accountPath(id))")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirestoreRESTError.network }
        if http.statusCode == 404 { return false }
        if http.statusCode == 200 { return true }
        if http.statusCode == 403 { return false }
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
            path: accountPath(accountId),
            body: body,
            fieldPaths: ["label", "updatedAt"]
        )
    }

    func updateOAuthRefreshSuccess(
        accountId: String,
        accessToken: String,
        refreshToken: String,
        expiresAt: Double
    ) async throws {
        let now = FirestoreValue.timestamp()
        let body: [String: Any] = [
            "fields": [
                "accessToken": FirestoreValue.string(accessToken),
                "refreshToken": FirestoreValue.string(refreshToken),
                "expiresAt": FirestoreValue.number(expiresAt),
                "lastRefreshStatus": FirestoreValue.string("success"),
                "lastError": FirestoreValue.null(),
                "consecutiveFailures": FirestoreValue.integer(0),
                "lastRefreshedAt": now,
                "updatedAt": now,
            ],
        ]
        try await patch(
            path: accountPath(accountId),
            body: body,
            fieldPaths: [
                "accessToken",
                "refreshToken",
                "expiresAt",
                "lastRefreshStatus",
                "lastError",
                "consecutiveFailures",
                "lastRefreshedAt",
                "updatedAt",
            ]
        )
    }

    func updateOAuthRefreshFailure(
        accountId: String,
        error: String,
        consecutiveFailures: Int
    ) async throws {
        let now = FirestoreValue.timestamp()
        let body: [String: Any] = [
            "fields": [
                "lastRefreshStatus": FirestoreValue.string("failed"),
                "lastError": FirestoreValue.string(error),
                "consecutiveFailures": FirestoreValue.integer(consecutiveFailures),
                "updatedAt": now,
            ],
        ]
        try await patch(
            path: accountPath(accountId),
            body: body,
            fieldPaths: [
                "lastRefreshStatus",
                "lastError",
                "consecutiveFailures",
                "updatedAt",
            ]
        )
    }

    func updateUsageSnapshot(
        accountId: String,
        fiveHourAvailable: Double?,
        weeklyAvailable: Double?
    ) async throws {
        let now = FirestoreValue.timestamp()
        var fields: [String: Any] = [
            "usageUpdatedAt": now,
            "updatedAt": now,
        ]
        var fieldPaths = ["usageUpdatedAt", "updatedAt"]

        if let fiveHourAvailable {
            fields["fiveHourAvailable"] = FirestoreValue.number(fiveHourAvailable)
            fieldPaths.append("fiveHourAvailable")
        }
        if let weeklyAvailable {
            fields["weeklyAvailable"] = FirestoreValue.number(weeklyAvailable)
            fieldPaths.append("weeklyAvailable")
        }

        let body: [String: Any] = ["fields": fields]
        try await patch(
            path: accountPath(accountId),
            body: body,
            fieldPaths: fieldPaths
        )
    }

    func createAccount(
        docId: String,
        label: String,
        credentials: ClaudeOAuthCredentials
    ) async throws {
        guard !ownerUid.isEmpty else {
            throw FirestoreRESTError.permissionDenied
        }

        let now = FirestoreValue.timestamp()
        let body: [String: Any] = [
            "fields": [
                "ownerUid": FirestoreValue.string(ownerUid),
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

        let url = URL(string: "\(baseURL)/\(accountsCollectionPath)?documentId=\(docId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await session.validIDToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(data: data, response: response)
    }

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
            let scopes = FirestoreValue.stringArrayValue(fields["scopes"])
        else { return nil }

        let active = FirestoreValue.boolValue(fields["active"]) ?? true
        let lastRefreshStatus = FirestoreValue.stringValue(fields["lastRefreshStatus"]) ?? "never"

        return ClaudeAccount(
            id: id,
            ownerUid: FirestoreValue.stringValue(fields["ownerUid"]),
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
            updatedAt: FirestoreValue.dateValue(fields["updatedAt"]),
            fiveHourAvailable: FirestoreValue.numberValue(fields["fiveHourAvailable"]),
            weeklyAvailable: FirestoreValue.numberValue(fields["weeklyAvailable"]),
            usageUpdatedAt: FirestoreValue.dateValue(fields["usageUpdatedAt"])
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
            return "Firestore access denied — publish the updated security rules in Firebase Console (see firestore.rules in this repo)."
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
        guard value.isFinite else {
            return ["doubleValue": "0"]
        }
        if value.rounded() == value,
           value >= Double(Int.min),
           value <= Double(Int.max)
        {
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
        if let integer = dict["integerValue"] {
            return numericPrimitive(integer)
        }
        if let double = dict["doubleValue"] {
            return numericPrimitive(double)
        }
        return nil
    }

    private static func numericPrimitive(_ value: Any) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
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
