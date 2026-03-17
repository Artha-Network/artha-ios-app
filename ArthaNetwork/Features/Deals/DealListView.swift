import SwiftUI

struct DealListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DealListViewModel()

    var body: some View {
        List {
            // MARK: - Stats

            if !viewModel.deals.isEmpty {
                dealStatsSection
            }

            // MARK: - Status Filter

            if !viewModel.deals.isEmpty {
                statusFilterSection
            }

            // MARK: - Deal List

            if viewModel.filteredDeals.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                if viewModel.deals.isEmpty {
                    ContentUnavailableView(
                        "No Deals Yet",
                        systemImage: "doc.text",
                        description: Text("Create your first escrow deal to get started.")
                    )
                } else {
                    ContentUnavailableView(
                        "No Matching Deals",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search or filter.")
                    )
                }
            }

            ForEach(viewModel.filteredDeals) { deal in
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
        .searchable(text: $viewModel.searchText, prompt: "Search by title, ID, or wallet")
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

    // MARK: - Stats Section

    private var dealStatsSection: some View {
        Section {
            HStack(spacing: 0) {
                statCell("Total", value: viewModel.totalDealCount)
                Divider().frame(height: 32)
                statCell("Shown", value: viewModel.filteredDeals.count)
                Divider().frame(height: 32)
                statCell("Active", value: viewModel.activeDealCount)
                Divider().frame(height: 32)
                statCell("As Buyer", value: viewModel.asBuyerCount)
            }
        }
        .listRowInsets(EdgeInsets())
    }

    private func statCell(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Status Filter Section

    private var statusFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", isSelected: viewModel.selectedStatus == nil) {
                        viewModel.selectedStatus = nil
                    }
                    ForEach(DealStatus.allCases, id: \.self) { status in
                        filterChip(status.displayLabel, isSelected: viewModel.selectedStatus == status) {
                            viewModel.selectedStatus = status
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
