import Foundation

enum ClaudeOAuthRefreshService {
    private static let clientID = "YOUR_CLAUDE_OAUTH_CLIENT_ID"
    private static let tokenEndpoint = URL(string: "https://your-oauth-provider.example/v1/oauth/token")!
    private static let defaultExpiresIn: TimeInterval = 28_800
    private static let maxRetries = 3
    private static let initialRetryDelay: TimeInterval = 30

    struct Result {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Double
    }

    static func refresh(refreshToken: String) async throws -> Result {
        var attempt = 0
        var retryDelay = initialRetryDelay

        while attempt < maxRetries {
            attempt += 1

            do {
                return try await performRefresh(refreshToken: refreshToken)
            } catch let error as ClaudeOAuthRefreshError {
                if case .rateLimited = error, attempt < maxRetries {
                    try await Task.sleep(for: .seconds(retryDelay))
                    retryDelay *= 2
                    continue
                }
                throw error
            }
        }

        throw ClaudeOAuthRefreshError.rateLimited
    }

    private static func performRefresh(refreshToken: String) async throws -> Result {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Claudamangala/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let encodedRefreshToken = formURLEncode(refreshToken)
        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(encodedRefreshToken)",
            "client_id=\(clientID)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeOAuthRefreshError.network
        }

        if http.statusCode == 429 {
            throw ClaudeOAuthRefreshError.rateLimited
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeOAuthRefreshError.http(http.statusCode, "Invalid response")
        }

        if let accessToken = json["access_token"] as? String,
           let newRefreshToken = json["refresh_token"] as? String
        {
            let expiresIn = number(from: json["expires_in"]) ?? defaultExpiresIn
            let expiresAt = Date().timeIntervalSince1970 * 1000 + expiresIn * 1000
            return Result(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                expiresAt: expiresAt
            )
        }

        throw ClaudeOAuthRefreshError.http(http.statusCode, parseErrorMessage(json: json, statusCode: http.statusCode))
    }

    private static func number(from value: Any?) -> TimeInterval? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return TimeInterval(number)
        case let string as String:
            return TimeInterval(string)
        default:
            return nil
        }
    }

    private static func parseErrorMessage(json: [String: Any], statusCode: Int) -> String {
        if let type = json["type"] as? String {
            let message = json["message"] as? String ?? "unknown"
            return "\(type): \(message)"
        }

        if let error = json["error"] as? String {
            if let description = json["error_description"] as? String {
                return "\(error): \(description)"
            }
            return error
        }

        if let error = json["error"] as? [String: Any] {
            let type = error["type"] as? String ?? "oauth_error"
            let message = error["message"] as? String ?? "unknown"
            return "\(type): \(message)"
        }

        return "HTTP \(statusCode)"
    }

    private static func formURLEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum ClaudeOAuthRefreshError: LocalizedError {
    case network
    case rateLimited
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Could not reach Claude OAuth."
        case .rateLimited:
            return "Claude OAuth is rate-limited — try again in a few minutes."
        case .http(_, let detail):
            return "Token refresh failed (\(detail))."
        }
    }
}
