import Foundation

struct ClaudeAccountUsage: Equatable {
    var fiveHourAvailable: Double?
    var weeklyAvailable: Double?
    var isLoading = false
    var hasError = false

    static let loading = ClaudeAccountUsage(isLoading: true)
    static let unavailable = ClaudeAccountUsage(hasError: true)

    var fiveHourDisplay: String {
        guard let value = fiveHourAvailable else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    var weeklyDisplay: String {
        guard let value = weeklyAvailable else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    func availabilityColor(for value: Double?) -> UsageLevel {
        guard let value else { return .unknown }
        if value <= 10 { return .critical }
        if value <= 30 { return .low }
        return .healthy
    }
}

enum UsageLevel {
    case healthy, low, critical, unknown

    var colorName: String {
        switch self {
        case .healthy: return "green"
        case .low: return "orange"
        case .critical: return "red"
        case .unknown: return "secondary"
        }
    }
}
