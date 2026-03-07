import Foundation

enum APIEndpoints {
    // MARK: - Auth
    static let signIn = "/auth/sign-in"
    static let authMe = "/auth/me"
    static let logout = "/auth/logout"
    static let keepalive = "/auth/keepalive"

    // MARK: - User
    static let usersMe = "/api/users/me"

    // MARK: - Deals
    static let deals = "/api/deals"
    static func deal(_ id: String) -> String { "/api/deals/\(id)" }
    static let recentEvents = "/api/deals/events/recent"
    static let carEscrowPlan = "/api/deals/car-escrow/plan"

    // MARK: - Escrow Actions
    static let actionInitiate = "/actions/initiate"
    static let actionFund = "/actions/fund"
    static let actionRelease = "/actions/release"
    static let actionRefund = "/actions/refund"
    static let actionOpenDispute = "/actions/open-dispute"
    static let actionConfirm = "/actions/confirm"

    // MARK: - Evidence
    static func evidence(_ dealId: String) -> String { "/api/deals/\(dealId)/evidence" }
    static func evidenceUpload(_ dealId: String) -> String { "/api/deals/\(dealId)/evidence/upload" }

    // MARK: - Arbitration
    static func arbitrate(_ dealId: String) -> String { "/api/deals/\(dealId)/arbitrate" }
    static func resolution(_ dealId: String) -> String { "/api/deals/\(dealId)/resolution" }

    // MARK: - AI
    static let generateContract = "/api/ai/generate-contract"

    // MARK: - Notifications
    static let notifications = "/api/notifications"
    static func markRead(_ id: String) -> String { "/api/notifications/\(id)/read" }
    static let markAllRead = "/api/notifications/mark-all-read"

    // MARK: - Government
    static func vinTitle(_ vin: String) -> String { "/gov/title/\(vin)" }

    // MARK: - Analytics
    static let events = "/api/events"
}
