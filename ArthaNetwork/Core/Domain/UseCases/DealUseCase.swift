import Foundation

/// Handles deal listing, detail fetching, and deletion.
struct DealUseCase {
    private let dealRepo: DealRepository

    init(dealRepo: DealRepository = .init()) {
        self.dealRepo = dealRepo
    }

    func fetchDeals(wallet: String, offset: Int = 0, limit: Int = 10) async throws -> DealsPage {
        try await dealRepo.fetchDeals(wallet: wallet, offset: offset, limit: limit)
    }

    func fetchDeal(id: String) async throws -> Deal {
        try await dealRepo.fetchDeal(id: id)
    }

    func deleteDeal(id: String) async throws {
        try await dealRepo.deleteDeal(id: id)
    }

    func fetchRecentEvents(wallet: String, limit: Int = 10) async throws -> [DealEventRow] {
        try await dealRepo.fetchRecentEvents(wallet: wallet, limit: limit)
    }
}
