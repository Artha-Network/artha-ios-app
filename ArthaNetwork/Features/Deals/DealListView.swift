import SwiftUI

struct DealListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DealListViewModel()

    var body: some View {
        List {
            if viewModel.deals.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                ContentUnavailableView(
                    "No Deals Yet",
                    systemImage: "doc.text",
                    description: Text("Create your first escrow deal to get started.")
                )
            }

            ForEach(viewModel.deals) { deal in
                NavigationLink(value: AppRouter.Destination.dealDetail(deal.id)) {
                    DealCardView(deal: deal)
                }
            }

            if viewModel.hasMore {
                Button("Load More") {
                    Task { await viewModel.loadMore() }
                }
            }
        }
        .navigationTitle("Deals")
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading && viewModel.deals.isEmpty {
                ProgressView()
            }
        }
        .alert("Failed to Load Deals", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Retry") { Task { await viewModel.refresh() } }
            Button("Cancel", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            if let wallet = appState.currentUser?.walletAddress {
                viewModel.walletAddress = wallet
                await viewModel.loadDeals()
            }
        }
    }
}
