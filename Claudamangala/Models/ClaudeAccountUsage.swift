import Foundation

struct ClaudeAccountUsage: Equatable {
    var fiveHourAvailable: Double?
    var weeklyAvailable: Double?
    var isLoading = false
    var hasError = false
    var isStored = false

    static let loading = ClaudeAccountUsage(isLoading: true)

    var hasData: Bool {
        fiveHourAvailable != nil || weeklyAvailable != nil
    }

    static func fromStored(account: ClaudeAccount) -> ClaudeAccountUsage {
        guard account.hasStoredUsage else {
            return ClaudeAccountUsage(hasError: false)
        }
        return ClaudeAccountUsage(
            fiveHourAvailable: account.fiveHourAvailable,
            weeklyAvailable: account.weeklyAvailable,
            isStored: true
        )
    }

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
