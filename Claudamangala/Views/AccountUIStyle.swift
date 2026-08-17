import SwiftUI

enum AccountUIStyle: String, CaseIterable, Identifiable {
    case studio
    case card
    case compact
    case dashboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: return "Studio"
        case .card: return "Card"
        case .compact: return "Compact"
        case .dashboard: return "Dashboard"
        }
    }

    var subtitle: String {
        switch self {
        case .studio: return "Editorial glass with accent rail"
        case .card: return "Elevated cards with usage rings"
        case .compact: return "Dense chips and tight spacing"
        case .dashboard: return "Bold metrics and progress bars"
        }
    }
}
