import Foundation
import Observation

@Observable
final class DashboardViewModel {
    var recentDeals: [Deal] = []
    var totalDealCount = 0
    var recentEvents: [DealEventRow] = []
    var recentNotifications: [AppNotification] = []
    var usdcBalance: Double?
    var solBalance: Double?
    var reputationScore: Int?
    var completedDealCount = 0
    var isLoading = false
    var error: String?

    private let dealUseCase = DealUseCase()
    private let dealRepo = DealRepository()
    private let notifUseCase = NotificationUseCase()

    // MARK: - Computed

    var activeDealCount: Int {
        recentDeals.filter { !$0.status.isTerminal }.count
    }

    var inEscrowAmount: Double {
        recentDeals
            .filter { [DealStatus.FUNDED, .DISPUTED, .RESOLVED].contains($0.status) }
            .reduce(0) { $0 + $1.priceUsd }
    }

    /// Highest-priority deal that needs the user's attention.
    var urgentDeal: Deal? {
        recentDeals.first { $0.status == .DISPUTED }
            ?? recentDeals.first { $0.status == .RESOLVED }
            ?? recentDeals.first { $0.status == .FUNDED }
            ?? recentDeals.first { $0.status == .INIT }
    }

    var hasLowSOL: Bool {
        guard let sol = solBalance else { return false }
        return sol < 0.005
    }

    var reputationLabel: String {
        guard let score = reputationScore else { return "—" }
        if score >= 80 { return "Trusted" }
        if score >= 50 { return "Established" }
        if score > 0 { return "Building" }
        return "New"
    }

    // MARK: - Load

    func load(wallet: String) async {
        guard !wallet.isEmpty else { return }
        isLoading = true
        error = nil

        // Kick off all fetches concurrently.
        async let dealsResult    = dealUseCase.fetchDeals(wallet: wallet, offset: 0, limit: 6)
        async let eventsResult   = dealRepo.fetchRecentEvents(wallet: wallet, limit: 6)
        async let notifsResult   = notifUseCase.fetchNotifications(wallet: wallet, limit: 4)
        async let repResult      = fetchReputation(wallet: wallet)
        async let usdcResult     = SolanaClient.shared.getUSDCBalance(pubkey: wallet)
        async let solResult      = SolanaClient.shared.getBalance(pubkey: wallet)

        if let page = try? await dealsResult {
            recentDeals = page.deals
            totalDealCount = page.total
        }
        if let events = try? await eventsResult {
            recentEvents = events
        }
        if let page = try? await notifsResult {
            recentNotifications = page.notifications
        }
        if let rep = try? await repResult {
            reputationScore = rep.score
            completedDealCount = rep.completedDeals
        }
        if let usdc = try? await usdcResult {
            usdcBalance = usdc
        }
        if let lamports = try? await solResult {
            solBalance = Double(lamports) / 1_000_000_000
        }

        isLoading = false
    }

    func refresh(wallet: String) async {
        await load(wallet: wallet)
    }

    // MARK: - Private

    private func fetchReputation(wallet: String) async throws -> ReputationResponse {
        try await APIClient.shared.get(APIEndpoints.userReputation(wallet))
    }
}

private struct ReputationResponse: Decodable {
    let score: Int
    let completedDeals: Int
}
