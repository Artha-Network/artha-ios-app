import SwiftUI

struct Step3_ReviewFundView: View {
    let coordinator: EscrowFlowCoordinator
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = Step3ViewModel()

    var body: some View {
        Form {
            if let draft = coordinator.cache.draft {
                Section("Deal Summary") {
                    LabeledContent("Title", value: draft.title)
                    USDCAmountView(amount: draft.amount, label: "Amount")

                    let fee = draft.amount * 0.005
                    LabeledContent("Platform Fee (0.5%)", value: "$\(String(format: "%.2f", fee)) USDC")

                    let total = draft.amount + fee
                    LabeledContent("Total", value: "$\(String(format: "%.2f", total)) USDC")
                        .bold()
                }

                Section("Parties") {
                    if let wallet = appState.currentUser?.walletAddress {
                        LabeledContent("Seller (You)", value: wallet.prefix(6) + "\u{2026}" + wallet.suffix(4))
                    }
                    LabeledContent(
                        "Buyer",
                        value: draft.counterpartyWallet.prefix(6) + "\u{2026}" + draft.counterpartyWallet.suffix(4)
                    )
                }

                Section("Deadlines") {
                    LabeledContent("Funding", value: draft.fundingDeadline.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Delivery", value: draft.completionDeadline.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Dispute Window", value: draft.disputeDeadline.formatted(date: .abbreviated, time: .shortened))
                }

                if let vin = draft.vin {
                    Section("Vehicle") {
                        LabeledContent("VIN", value: vin)
                        if let make = draft.carMake, let model = draft.carModel {
                            let year = draft.carYear.map { "\($0) " } ?? ""
                            LabeledContent("Vehicle", value: "\(year)\(make) \(model)")
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        ErrorBanner(message: error)
                        Button("Retry") {
                            Task {
                                await viewModel.createEscrow(
                                    draft: draft,
                                    coordinator: coordinator,
                                    wallet: walletManager
                                )
                            }
                        }
                    }
                }

                Section {
                    Button("Create & Sign Escrow") {
                        Task {
                            await viewModel.createEscrow(
                                draft: draft,
                                coordinator: coordinator,
                                wallet: walletManager
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)
                    .frame(maxWidth: .infinity)

                    Text("Phantom will ask you to sign the initiation transaction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Step 3 of 3 — Review")
        .overlay {
            if viewModel.isLoading {
                EscrowSigningOverlay(step: viewModel.currentStep) {
                    viewModel.cancel(wallet: walletManager)
                }
            }
        }
    }
}

// MARK: - Signing Overlay

/// Step-aware full-screen overlay shown during the initiate → sign → submit flow.
private struct EscrowSigningOverlay: View {
    let step: Step3ViewModel.InitiateStep?
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)

                VStack(spacing: 6) {
                    Text(step?.statusText ?? "Creating escrow\u{2026}")
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

                // Cancel is only available when suspended waiting for the user to approve in Phantom.
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
