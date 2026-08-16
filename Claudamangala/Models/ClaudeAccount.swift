import Foundation

struct ClaudeAccount: Codable, Identifiable, Equatable {
    var id: String?
    var label: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
    var scopes: [String]
    var active: Bool

    var lastRefreshStatus: String
    var lastError: String?
    var consecutiveFailures: Int

    var lastRefreshedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    var expiresInDescription: String {
        let remainingMs = expiresAt - Date().timeIntervalSince1970 * 1000
        if remainingMs <= 0 { return "expired" }
        let minutes = Int(remainingMs / 60_000)
        if minutes < 60 { return "expires in \(minutes)m" }
        return "expires in \(minutes / 60)h \(minutes % 60)m"
    }

    var isExpiringSoon: Bool {
        let remainingMs = expiresAt - Date().timeIntervalSince1970 * 1000
        return remainingMs <= 2 * 60 * 60 * 1000
    }

    func credentialsClipboardJSON() throws -> String {
        let oauth: [String: Any] = [
            "accessToken": accessToken,
            "refreshToken": refreshToken,
            "expiresAt": expiresAt,
            "scopes": scopes,
        ]
        let wrapper: [String: Any] = ["claudeAiOauth": oauth]
        let data = try JSONSerialization.data(
            withJSONObject: wrapper,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let string = String(data: data, encoding: .utf8) else {
            throw ClipboardError.encodingFailed
        }
        return string
    }
}

enum ClipboardError: Error, LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Could not encode credentials for the clipboard."
        }
    }
}
