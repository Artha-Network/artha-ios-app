import Foundation

enum DealStatus: String, Codable, Sendable, CaseIterable {
    case INIT
    case FUNDED
    case DISPUTED
    case RESOLVED
    case RELEASED
    case REFUNDED

    var displayLabel: String {
        switch self {
        case .INIT: return "Created"
        case .FUNDED: return "Funded"
        case .DISPUTED: return "Disputed"
        case .RESOLVED: return "Resolved"
        case .RELEASED: return "Released"
        case .REFUNDED: return "Refunded"
        }
    }

    var isTerminal: Bool {
        self == .RELEASED || self == .REFUNDED
    }

    var canDispute: Bool {
        self == .FUNDED
    }

    var canFund: Bool {
        self == .INIT
    }

    var canDelete: Bool {
        self == .INIT
    }

    var canRelease: Bool {
        self == .FUNDED || self == .RESOLVED
    }

    var canRefund: Bool {
        self == .FUNDED || self == .RESOLVED
    }
}
