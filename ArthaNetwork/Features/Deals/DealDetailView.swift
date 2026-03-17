import SwiftUI

struct DealDetailView: View {
    let dealId: String
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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
                    statusContextCard(deal)
                    usdcBalanceSection(deal)
                    dealDetails(deal)
                    if deal.vin != nil {
                        vinTitleCard(deal)
                    }
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
            // Start VIN title polling if deal has a VIN
            if let vin = viewModel.deal?.vin, !vin.isEmpty {
                viewModel.startTitlePolling(vin: vin)
            }
            // Start USDC balance polling if buyer viewing INIT deal
            let myWallet = appState.currentUser?.walletAddress ?? ""
            if viewModel.deal?.status == .INIT,
               viewModel.deal?.buyerWallet == myWallet,
               !myWallet.isEmpty {
                viewModel.startBalancePolling(pubkey: myWallet)
            }
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
                if let feeBps = deal.feeBps, feeBps > 0 {
                    LabeledContent("Platform Fee") {
                        Text(String(format: "%.1f%%", Double(feeBps) / 100.0))
                            .foregroundStyle(.secondary)
                    }
                }
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
                if let fundedAt = deal.fundedAt {
                    LabeledContent("Funded") {
                        Text(fundedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                if let deadline = deal.deliverDeadline {
                    LabeledContent("Delivery By") {
                        deadlineLabel(deadline, isTerminal: deal.status.isTerminal)
                    }
                }
                if let disputeDeadline = deal.disputeDeadline {
                    LabeledContent("Dispute Window Ends") {
                        deadlineLabel(disputeDeadline, isTerminal: deal.status.isTerminal)
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

    // MARK: - USDC Balance

    @ViewBuilder
    private func usdcBalanceSection(_ deal: Deal) -> some View {
        let myWallet = appState.currentUser?.walletAddress ?? ""
        let isBuyer = deal.buyerWallet == myWallet

        if deal.status == .INIT && isBuyer {
            if viewModel.hasInsufficientUSDC {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Insufficient USDC Balance", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                        if let balance = viewModel.usdcBalance {
                            Text("Your wallet has \(String(format: "%.2f", balance)) USDC but this deal requires \(String(format: "%.2f", deal.priceUsd * 1.005)) USDC (including 0.5% fee).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("You need devnet USDC tokens (not SOL) to fund this escrow. SOL is only used for transaction fees.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .backgroundStyle(Color.red.opacity(0.04))
            } else if let balance = viewModel.usdcBalance {
                GroupBox {
                    HStack {
                        Label("USDC Balance", systemImage: "creditcard")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(String(format: "%.2f", balance)) USDC")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            } else if viewModel.isBalanceLoading {
                GroupBox {
                    HStack {
                        Label("Checking balance…", systemImage: "creditcard")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                }
            }
        }
    }

    // MARK: - VIN Title Card

    @ViewBuilder
    private func vinTitleCard(_ deal: Deal) -> some View {
        if let title = viewModel.vehicleTitle {
            let isTransferred = title.isTransferred
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Vehicle Title Status", systemImage: "car.fill")
                        .font(.subheadline.bold())

                    LabeledContent("VIN") {
                        Text(title.vin)
                            .font(.caption.monospaced())
                    }

                    LabeledContent("Title Status") {
                        Text(isTransferred ? "Transferred" : "Pending")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isTransferred ? Color.green.opacity(0.15) : Color.yellow.opacity(0.15))
                            .foregroundStyle(isTransferred ? .green : .orange)
                            .clipShape(Capsule())
                    }

                    LabeledContent("Current Owner") {
                        Text(title.currentOwnerWallet.prefix(6) + "..." + title.currentOwnerWallet.suffix(4))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let transferDate = title.transferDate {
                        LabeledContent("Transfer Date") {
                            Text(transferDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isTransferred && deal.status == .FUNDED {
                        Label("Title has been transferred. You may now release the funds.",
                              systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }
                }
            }
            .backgroundStyle(isTransferred ? Color.green.opacity(0.04) : Color.clear)
        } else if let vin = deal.vin, !vin.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Vehicle Title Status", systemImage: "car.fill")
                        .font(.subheadline.bold())
                    LabeledContent("VIN") {
                        Text(vin)
                            .font(.caption.monospaced())
                    }
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking title status…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Deadline Helper

    @ViewBuilder
    private func deadlineLabel(_ date: Date, isTerminal: Bool) -> some View {
        let isPast = date < Date()
        VStack(alignment: .trailing, spacing: 2) {
            Text(date.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(isPast && !isTerminal ? .red : .primary)
            if !isTerminal {
                Text(isPast ? "Overdue" : deadlineCountdown(date))
                    .font(.caption2)
                    .foregroundStyle(isPast ? .red : .green)
            }
        }
    }

    private func deadlineCountdown(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let days = Int(interval / 86400)
        let hours = Int(interval / 3600) % 24
        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(hours)h remaining"
        } else {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m remaining"
        }
    }

    // MARK: - Status Context Card

    @ViewBuilder
    private func statusContextCard(_ deal: Deal) -> some View {
        let myWallet = appState.currentUser?.walletAddress ?? ""
        let isBuyer = deal.buyerWallet == myWallet

        switch deal.status {
        case .INIT:
            if isBuyer {
                contextBox(icon: "doc.text.magnifyingglass", color: .blue, title: "Contract Review") {
                    Text("You have been invited to this escrow deal. Review the terms and contract below, then fund the escrow to lock your USDC on-chain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let amount = deal.priceUsd as Double? {
                        Text("By funding, \(String(format: "%.2f", amount)) USDC + 0.5% fee will be transferred to the escrow vault.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .FUNDED:
            contextBox(icon: "shippingbox", color: .green, title: "Awaiting Delivery") {
                Text("The escrow is funded. The seller should deliver the goods or services before the deadline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let deadline = deal.deliverDeadline {
                    let isPast = deadline < Date()
                    Label(
                        isPast ? "Delivery deadline has passed" : "Delivery deadline: \(deadline.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: isPast ? "exclamationmark.triangle.fill" : "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(isPast ? .red : .secondary)
                }
                Text("If there's a problem, either party can open a dispute before the dispute window closes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .DISPUTED:
            contextBox(icon: "exclamationmark.bubble.fill", color: .orange, title: "Dispute In Progress") {
                VStack(alignment: .leading, spacing: 6) {
                    disputeStep(number: 1, text: "Dispute opened — funds locked on-chain", isDone: true)
                    disputeStep(number: 2, text: "Both parties submit evidence", isDone: false)
                    disputeStep(number: 3, text: "AI arbiter issues binding verdict (10–30s)", isDone: false)
                }
            }

        case .RESOLVED:
            if let resolution = deal.aiResolution {
                let isRelease = resolution.outcome == "RELEASE"
                contextBox(
                    icon: isRelease ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill",
                    color: isRelease ? .green : .orange,
                    title: isRelease ? "Verdict: Release to Seller" : "Verdict: Refund to Buyer"
                ) {
                    if let pct = resolution.confidence as Double? {
                        HStack(spacing: 6) {
                            Text("AI Confidence:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(pct * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(pct > 0.7 ? .green : .orange)
                        }
                    }
                    if let reason = resolution.reasonShort {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                contextBox(icon: "checkmark.seal", color: .purple, title: "Resolved") {
                    Text("The AI arbiter has issued a verdict for this deal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .RELEASED:
            terminalBox(icon: "checkmark.circle.fill", color: .green, text: "Funds have been released to the seller. This deal is complete.")

        case .REFUNDED:
            terminalBox(icon: "arrow.uturn.left.circle.fill", color: .orange, text: "Funds have been refunded to the buyer. This deal is complete.")
        }
    }

    @ViewBuilder
    private func contextBox<Content: View>(
        icon: String, color: Color, title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                content()
            }
        }
        .backgroundStyle(color.opacity(0.04))
    }

    @ViewBuilder
    private func terminalBox(icon: String, color: Color, text: String) -> some View {
        GroupBox {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func disputeStep(number: Int, text: String, isDone: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 20, height: 20)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(isDone ? .primary : .secondary)
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
                .disabled(viewModel.currentAction != nil || viewModel.hasInsufficientUSDC)
            }

            if deal.status.canRelease && isSeller {
                let isResolved = deal.status == .RESOLVED
                Button {
                    showReleaseConfirmation = true
                } label: {
                    Label(isResolved ? "Claim Funds" : "Release Funds",
                          systemImage: isResolved ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.currentAction != nil)
            }

            if deal.status.canRefund && isBuyer {
                let isResolved = deal.status == .RESOLVED
                Button {
                    showRefundConfirmation = true
                } label: {
                    Label(isResolved ? "Claim Refund" : "Refund to Me",
                          systemImage: "arrow.uturn.backward.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
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

            if deal.status == .DISPUTED || deal.status == .RESOLVED {
                NavigationLink(value: AppRouter.Destination.evidence(deal.id)) {
                    Label("View Evidence", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if deal.status == .DISPUTED {
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
                    VStack(alignment: .leading, spacing: 4) {
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
                        Button {
                            openExplorer(txSig: event.txSig)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text(event.txSig.prefix(8) + "..." + event.txSig.suffix(4))
                            }
                            .font(.caption2.monospaced())
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    if event.id != events.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func openExplorer(txSig: String) {
        let cluster = AppConfiguration.solanaCluster
        let query = cluster == "mainnet-beta" ? "" : "?cluster=\(cluster)"
        guard let url = URL(string: "https://explorer.solana.com/tx/\(txSig)\(query)") else { return }
        openURL(url)
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
