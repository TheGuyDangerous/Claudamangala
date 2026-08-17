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
        Self.usedDisplay(fromAvailable: fiveHourAvailable)
    }

    var weeklyDisplay: String {
        Self.usedDisplay(fromAvailable: weeklyAvailable)
    }

    static func usedValue(fromAvailable available: Double) -> Double {
        min(100, max(0, 100 - available))
    }

    static func usedDisplay(fromAvailable available: Double?) -> String {
        guard let available else { return "—" }
        return "\(Int(usedValue(fromAvailable: available).rounded()))%"
    }
}
