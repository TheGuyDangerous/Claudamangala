import Foundation

enum LocalRefreshSchedule: String, CaseIterable, Identifiable {
    case off
    case every1Hour
    case every2Hours
    case every4Hours
    case every6Hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .every1Hour:
            return "Every 1 hour"
        case .every2Hours:
            return "Every 2 hours"
        case .every4Hours:
            return "Every 4 hours"
        case .every6Hours:
            return "Every 6 hours"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .every1Hour:
            return 3_600
        case .every2Hours:
            return 7_200
        case .every4Hours:
            return 14_400
        case .every6Hours:
            return 21_600
        }
    }
}

enum LocalRefreshSchedulePreferences {
    static let scheduleKey = "localRefreshSchedule"
    static let lastRunAtKey = "localRefreshScheduleLastRunAt"

    static var schedule: LocalRefreshSchedule {
        get {
            guard let raw = UserDefaults.standard.string(forKey: scheduleKey),
                  let value = LocalRefreshSchedule(rawValue: raw)
            else {
                return .off
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: scheduleKey)
        }
    }

    static var lastRunAt: Date? {
        get {
            let value = UserDefaults.standard.double(forKey: lastRunAtKey)
            guard value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: lastRunAtKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastRunAtKey)
            }
        }
    }
}
