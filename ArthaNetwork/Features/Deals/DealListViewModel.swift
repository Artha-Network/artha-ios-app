import Foundation
import Observation

@Observable
final class DealListViewModel {
    var deals: [Deal] = []
    var isLoading = false
    var error: String?
    var walletAddress = ""
    var hasMore = false

    // MARK: - Search & Filter

    var searchText = ""
    var selectedStatus: DealStatus?

    /// Total deal count from the server (across all pages).
    private(set) var totalDealCount = 0

    var filteredDeals: [Deal] {
        var result = deals
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { deal in
                (deal.title?.lowercased().contains(query) ?? false)
                    || deal.id.lowercased().contains(query)
                    || deal.buyerWallet.lowercased().contains(query)
                    || deal.sellerWallet.lowercased().contains(query)
            }
        }
        return result
    }

    var activeDealCount: Int {
        deals.filter { !$0.status.isTerminal }.count
    }

    var asBuyerCount: Int {
        deals.filter { $0.buyerWallet.lowercased() == walletAddress.lowercased() }.count
    }

    private var offset = 0
    private let limit = 10
    private let dealUseCase = DealUseCase()

    func loadDeals() async {
        guard !walletAddress.isEmpty else { return }
        isLoading = true
        do {
            let page = try await dealUseCase.fetchDeals(
                wallet: walletAddress, offset: 0, limit: limit
            )
            deals = page.deals
            totalDealCount = page.total
            offset = page.deals.count
            hasMore = offset < page.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            let page = try await dealUseCase.fetchDeals(
                wallet: walletAddress, offset: offset, limit: limit
            )
            deals.append(contentsOf: page.deals)
            offset += page.deals.count
            hasMore = offset < page.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        offset = 0
        await loadDeals()
    }

    func deleteDeal(id: String) async {
        do {
            try await dealUseCase.deleteDeal(id: id)
            deals.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
