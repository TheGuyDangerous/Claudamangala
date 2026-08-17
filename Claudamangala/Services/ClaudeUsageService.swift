import Foundation

enum ClaudeUsageService {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch(accessToken: String) async throws -> ClaudeAccountUsage {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeUsageError.network
        }
        guard http.statusCode == 200 else {
            throw ClaudeUsageError.http(http.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let fiveHour = json?["five_hour"] as? [String: Any]
        let sevenDay = json?["seven_day"] as? [String: Any]

        let fiveHourUsed = Self.number(from: fiveHour?["utilization"])
        let weeklyUsed = Self.number(from: sevenDay?["utilization"])

        guard weeklyUsed != nil else {
            throw ClaudeUsageError.parse
        }

        return ClaudeAccountUsage(
            fiveHourAvailable: fiveHourUsed.map { 100 - $0 },
            weeklyAvailable: weeklyUsed.map { 100 - $0 }
        )
    }

    private static func number(from value: Any?) -> Double? {
        switch value {
        case let number as Double: return number
        case let number as Int: return Double(number)
        case let string as String: return Double(string)
        default: return nil
        }
    }
}

enum ClaudeUsageError: Error {
    case network
    case http(Int)
    case parse
}
