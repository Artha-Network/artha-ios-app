import SwiftUI

struct DealDetailView: View {
    let dealId: String
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = DealDetailViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showFundConfirmation = false
    @State private var showReleaseConfirmation = false
    @State private var showRefundConfirmation = false
    @State private var showDisputeConfirmation = false

    var body: some View {
        ScrollView {
            if let deal = viewModel.deal {
                VStack(alignment: .leading, spacing: 20) {
                    dealHeader(deal)
                    dealDetails(deal)
                    if let contract = deal.contract, !contract.isEmpty {
                        contractSection(contract)
                    }
                    dealActions(deal)
                    if let events = deal.onchainEvents, !events.isEmpty {
                        activitySection(events)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Deal")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading { ProgressView() }
            if viewModel.currentAction != nil {
                DealActionOverlay(step: viewModel.currentAction) {
                    viewModel.cancelAction(wallet: walletManager)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Retry") { Task { await viewModel.loadDeal(id: dealId) } }
            Button("OK", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .confirmationDialog(
            "Delete this deal?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteDeal(id: dealId) }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Fund Escrow",
            isPresented: $showFundConfirmation,
            titleVisibility: .visible
        ) {
            Button("Fund with USDC") {
                Task { await viewModel.fund(dealId: dealId, wallet: walletManager) }
            }
        } message: {
            if let amount = viewModel.deal?.priceUsd {
                Text("You will send \(String(format: "%.2f", amount)) USDC + 0.5% platform fee to the escrow. Phantom will ask you to sign.")
            }
        }
        .confirmationDialog(
            "Release Funds",
            isPresented: $showReleaseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Release to Seller") {
                Task { await viewModel.release(dealId: dealId, wallet: walletManager) }
            }
        } message: {
            Text("This will release the escrowed funds to the seller. This cannot be undone.")
        }
        .confirmationDialog(
            "Refund Escrow",
            isPresented: $showRefundConfirmation,
            titleVisibility: .visible
        ) {
            Button("Refund to Me", role: .destructive) {
                Task { await viewModel.refund(dealId: dealId, wallet: walletManager) }
            }
        } message: {
            Text("This will return the escrowed funds to your wallet. This cannot be undone.")
        }
        .confirmationDialog(
            "Open Dispute",
            isPresented: $showDisputeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Open Dispute", role: .destructive) {
                Task { await viewModel.openDispute(dealId: dealId, wallet: walletManager) }
            }
        } message: {
            Text("This will lock the deal and start a dispute. The AI arbiter will review evidence from both parties.")
        }
        .onChange(of: viewModel.wasDeleted) { _, deleted in
            if deleted { dismiss() }
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .task {
            await viewModel.loadDeal(id: dealId)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func dealHeader(_ deal: Deal) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.title ?? "Untitled Deal")
                    .font(.title2.bold())
                if let description = deal.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: deal.status)
        }
    }

    @ViewBuilder
    private func dealDetails(_ deal: Deal) -> some View {
        GroupBox("Deal Details") {
            VStack(alignment: .leading, spacing: 10) {
                USDCAmountView(amount: deal.priceUsd, label: "Amount")
                Divider()
                walletRow(label: "Seller",
                          displayName: deal.seller?.displayName,
                          wallet: deal.sellerWallet)
                walletRow(label: "Buyer",
                          displayName: deal.buyer?.displayName,
                          wallet: deal.buyerWallet)
                if deal.deliverDeadline != nil || deal.disputeDeadline != nil {
                    Divider()
                }
                if let deadline = deal.deliverDeadline {
                    LabeledContent("Delivery By") {
                        Text(deadline.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(
                                deadline < Date() && !deal.status.isTerminal ? .red : .primary
                            )
                    }
                }
                if let disputeDeadline = deal.disputeDeadline {
                    LabeledContent("Dispute Window Ends") {
                        Text(disputeDeadline.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(
                                disputeDeadline < Date() && !deal.status.isTerminal ? .red : .primary
                            )
                    }
                }
                if let vin = deal.vin {
                    Divider()
                    LabeledContent("VIN", value: vin)
                }
            }
        }
    }

    @ViewBuilder
    private func walletRow(label: String, displayName: String?, wallet: String) -> some View {
        LabeledContent(label) {
            VStack(alignment: .trailing, spacing: 2) {
                if let name = displayName, !name.isEmpty {
                    Text(name).font(.subheadline)
                }
                Text(wallet.prefix(6) + "..." + wallet.suffix(4))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func contractSection(_ contract: String) -> some View {
        GroupBox("Contract") {
            MarkdownView(markdown: contract, font: .caption)
                .frame(maxHeight: 280)
        }
    }

    @ViewBuilder
    private func dealActions(_ deal: Deal) -> some View {
        let myWallet = appState.currentUser?.walletAddress ?? ""
        let isBuyer = deal.buyerWallet == myWallet
        let isSeller = deal.sellerWallet == myWallet

        VStack(spacing: 12) {
            if let actionError = viewModel.actionError {
                ErrorBanner(message: actionError)
            }

            if deal.status.canFund && isBuyer {
                Button {
                    showFundConfirmation = true
                } label: {
                    Label("Fund Escrow", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.currentAction != nil)
            }

            if deal.status.canRelease && isSeller {
                Button {
                    showReleaseConfirmation = true
                } label: {
                    Label("Release Funds", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.currentAction != nil)
            }

            if deal.status.canRefund && isBuyer {
                Button {
                    showRefundConfirmation = true
                } label: {
                    Label("Refund to Me", systemImage: "arrow.uturn.backward.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(viewModel.currentAction != nil)
            }

            if deal.status.canDispute {
                Button {
                    showDisputeConfirmation = true
                } label: {
                    Label("Open Dispute", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(viewModel.currentAction != nil)
            }

            if deal.status == .DISPUTED {
                NavigationLink(value: AppRouter.Destination.evidence(deal.id)) {
                    Label("View Evidence", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                NavigationLink(value: AppRouter.Destination.dispute(deal.id)) {
                    Label("Dispute Details", systemImage: "exclamationmark.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if deal.status == .RESOLVED {
                NavigationLink(value: AppRouter.Destination.dealResolution(deal.id)) {
                    Label("View Resolution", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            }

            if deal.status.canDelete && isSeller {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Deal", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func activitySection(_ events: [OnchainEvent]) -> some View {
        GroupBox("Activity") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(events) { event in
                    HStack {
                        Circle()
                            .fill(.blue.opacity(0.7))
                            .frame(width: 6, height: 6)
                        Text(event.instruction
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized)
                        .font(.caption.bold())
                        Spacer()
                        if let date = event.createdAt {
                            Text(date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if event.id != events.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Signing Overlay

private struct DealActionOverlay: View {
    let step: DealDetailViewModel.ActionStep?
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)

                VStack(spacing: 6) {
                    Text(step?.statusText ?? "Processing…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let hint = step?.hintText {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                }

                if step == .waitingForSignature {
                    Button(role: .destructive, action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
