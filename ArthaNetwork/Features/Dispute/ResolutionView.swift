import SwiftUI

struct ResolutionView: View {
    let dealId: String
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = ResolutionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let resolution = viewModel.resolution {
                    // Outcome header
                    outcomeHeader(resolution)

                    // Confidence
                    GroupBox("AI Confidence") {
                        VStack(alignment: .leading, spacing: 8) {
                            let pct = Int(resolution.confidence * 100)
                            Text("\(pct)%")
                                .font(.largeTitle.bold())
                            ProgressView(value: resolution.confidence)
                                .tint(resolution.confidence > 0.7 ? .green : .orange)
                            if let reason = resolution.reasonShort {
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Violated rules
                    if let rules = resolution.violatedRules, !rules.isEmpty {
                        GroupBox("Rules Applied") {
                            ForEach(rules, id: \.self) { rule in
                                Label(rule.replacingOccurrences(of: "_", with: " ").capitalized,
                                      systemImage: "checkmark.circle")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Execute button
                    if let wallet = appState.currentUser?.walletAddress {
                        let isSeller = viewModel.deal?.sellerWallet == wallet
                        let isBuyer = viewModel.deal?.buyerWallet == wallet
                        let outcome = resolution.outcome
                        let isDone = viewModel.deal?.status.isTerminal == true

                        if !isDone && ((outcome == "RELEASE" && isSeller) || (outcome == "REFUND" && isBuyer)) {
                            if let executeError = viewModel.executeError {
                                ErrorBanner(message: executeError)
                            }

                            Button {
                                Task { await viewModel.executeResolution(dealId: dealId, walletAddress: wallet, wallet: walletManager) }
                            } label: {
                                Label(
                                    outcome == "RELEASE" ? "Claim Funds" : "Claim Refund",
                                    systemImage: "arrow.down.circle.fill"
                                )
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(viewModel.currentAction != nil)
                        } else if isDone {
                            Label(
                                outcome == "RELEASE" ? "Funds Released" : "Refund Issued",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }

                } else if viewModel.isLoading {
                    ProgressView("Loading resolution...")
                        .padding(.top, 60)
                } else if let error = viewModel.error {
                    ErrorBanner(message: error)
                }
            }
            .padding()
        }
        .navigationTitle("Resolution")
        .overlay {
            if viewModel.currentAction != nil {
                ResolutionActionOverlay(step: viewModel.currentAction) {
                    viewModel.cancelExecution(wallet: walletManager)
                }
            }
        }
        .task {
            await viewModel.load(dealId: dealId)
        }
    }

    @ViewBuilder
    private func outcomeHeader(_ resolution: Resolution) -> some View {
        let isRelease = resolution.outcome == "RELEASE"
        GroupBox {
            VStack(spacing: 12) {
                Image(systemName: isRelease ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(isRelease ? .green : .orange)
                Text(isRelease ? "Funds Released to Seller" : "Refund to Buyer")
                    .font(.title3.bold())
                Text(isRelease ? "The arbiter determined the seller fulfilled their obligations." :
                        "The arbiter determined the buyer is entitled to a refund.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Signing Overlay

private struct ResolutionActionOverlay: View {
    let step: ResolutionViewModel.ActionStep?
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
