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
}
