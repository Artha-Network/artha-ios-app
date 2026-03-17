import SwiftUI

struct ResolutionView: View {
    let dealId: String
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.openURL) private var openURL
    @State private var viewModel = ResolutionViewModel()
    @State private var showHumanArbitrationConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let resolution = viewModel.resolution {
                    resolvedContent(resolution)
                } else if viewModel.isLoading && viewModel.resolution == nil {
                    awaitingContent
                } else if let error = viewModel.error {
                    ErrorBanner(message: error)
                } else {
                    awaitingContent
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
        .confirmationDialog(
            "Request Human Arbitration",
            isPresented: $showHumanArbitrationConfirm,
            titleVisibility: .visible
        ) {
            Button("Send Email to Arbiter", role: .destructive) {
                openHumanArbitrationEmail()
            }
        } message: {
            Text("A human arbiter will review all evidence and the AI verdict. This decision is final and cannot be appealed. Typical response time is 24–48 hours.")
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .task {
            await viewModel.load(dealId: dealId)
        }
    }

    // MARK: - Awaiting Resolution

    private var awaitingContent: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Awaiting Resolution")
                .font(.title3.bold())
            Text("The AI arbiter has not yet issued a verdict for this deal. If arbitration has been requested, the verdict typically arrives in 10–30 seconds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if viewModel.isPolling {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking for verdict…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Resolved Content

    @ViewBuilder
    private func resolvedContent(_ resolution: Resolution) -> some View {
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

        // Full AI Rationale
        if let rationale = resolution.rationaleCid, !rationale.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Reasoning", systemImage: "doc.text")
                        .font(.subheadline.bold())
                    Text(rationale)
                        .font(.caption)
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

        // Execute button or terminal state
        executeSection(resolution)

        // Human escalation
        humanArbitrationSection
    }

    // MARK: - Outcome Header

    @ViewBuilder
    private func outcomeHeader(_ resolution: Resolution) -> some View {
        let isRelease = resolution.outcome == "RELEASE"
        GroupBox {
            VStack(spacing: 12) {
                Image(systemName: isRelease ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(isRelease ? .green : .orange)
                Text(isRelease ? "Release Funds to Seller" : "Refund to Buyer")
                    .font(.title3.bold())
                Text(isRelease ? "The arbiter determined the seller fulfilled their obligations." :
                        "The arbiter determined the buyer is entitled to a refund.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let issuedAt = resolution.issuedAt {
                    Text("Resolved \(issuedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Execute Section

    @ViewBuilder
    private func executeSection(_ resolution: Resolution) -> some View {
        let wallet = appState.currentUser?.walletAddress ?? ""
        let isSeller = viewModel.deal?.sellerWallet == wallet
        let isBuyer = viewModel.deal?.buyerWallet == wallet
        let outcome = resolution.outcome
        let isDone = viewModel.deal?.status.isTerminal == true

        if let executeError = viewModel.executeError {
            ErrorBanner(message: executeError)
        }

        if isDone {
            Label(
                outcome == "RELEASE" ? "Funds Released" : "Refund Issued",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if (outcome == "RELEASE" && isSeller) || (outcome == "REFUND" && isBuyer) {
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
        } else if (outcome == "RELEASE" && isBuyer) || (outcome == "REFUND" && isSeller) {
            GroupBox {
                Label(
                    outcome == "RELEASE"
                        ? "The AI ruled in favor of the seller. The seller will claim the funds."
                        : "The AI ruled in favor of the buyer. The buyer will claim their refund.",
                    systemImage: "info.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Human Arbitration

    private var humanArbitrationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Request Human Arbitration", systemImage: "person.badge.shield.checkmark")
                    .font(.subheadline.bold())

                Text("If you disagree with the AI verdict, you can escalate to a human arbiter for a final review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How it works:")
                        .font(.caption.bold())
                    Group {
                        Text("• A human reviews all evidence and the AI verdict")
                        Text("• Full access to deal data and communication records")
                        Text("• Decision is final and binding — cannot be appealed")
                        Text("• Typical response time: 24–48 hours")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    showHumanArbitrationConfirm = true
                } label: {
                    Label("Request Human Arbitration", systemImage: "envelope")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    private func openHumanArbitrationEmail() {
        let subject = "Human Arbitration Request — Deal \(dealId.prefix(8))"
        let body = """
        Deal ID: \(dealId)
        Wallet: \(appState.currentUser?.walletAddress ?? "unknown")

        I am requesting human arbitration for this deal. Please review the evidence and AI verdict.
        """
        let encoded = "mailto:support@artha.network?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: encoded) {
            openURL(url)
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
