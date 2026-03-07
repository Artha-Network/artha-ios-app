import Foundation
import Observation

@Observable
final class DealListViewModel {
    var deals: [Deal] = []
    var isLoading = false
    var error: String?
    var walletAddress = ""
    var hasMore = false

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
