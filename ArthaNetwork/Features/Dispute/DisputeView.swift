import SwiftUI

struct DisputeView: View {
    let dealId: String
    @Environment(AppRouter.self) private var router
    @State private var viewModel = DisputeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Step 1 — Open Dispute
                stepCard(
                    number: 1,
                    title: "Open Dispute",
                    isDone: true,
                    content: {
                        Label("Dispute opened — funds are frozen on-chain.",
                              systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                )

                // Step 2 — Submit Evidence
                stepCard(
                    number: 2,
                    title: "Submit Evidence",
                    isDone: !viewModel.evidence.isEmpty,
                    content: {
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.evidence.isEmpty {
                                Text("No evidence submitted yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(viewModel.evidence.count) item(s) submitted")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Be specific. Include dates, amounts, screenshots, and communication records.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            NavigationLink(value: AppRouter.Destination.evidence(dealId)) {
                                Label("Submit Evidence", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                )

                // Step 3 — Request AI Arbitration
                stepCard(
                    number: 3,
                    title: "Request AI Arbitration",
                    isDone: viewModel.arbitrationResult != nil,
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            if viewModel.arbitrationResult != nil {
                                Label("AI verdict issued.", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)

                                Button {
                                    router.navigateToResolution(dealId)
                                } label: {
                                    Label("View Resolution", systemImage: "doc.text.magnifyingglass")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                            } else {
                                aiExplanationBox

                                Button {
                                    Task { await viewModel.requestArbitration() }
                                } label: {
                                    Label("Request AI Verdict", systemImage: "brain")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                                .disabled(!viewModel.canRequestArbitration || viewModel.isLoading)
                            }
                        }
                    }
                )

                if let error = viewModel.error {
                    ErrorBanner(message: error)
                }
            }
            .padding()
        }
        .navigationTitle("Dispute")
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Requesting arbitration…")
            }
        }
        .onAppear {
            Task { await viewModel.loadEvidence(dealId: dealId) }
        }
        .onChange(of: viewModel.arbitrationResult != nil) { _, hasResult in
            if hasResult {
                router.navigateToResolution(dealId)
            }
        }
    }

    // MARK: - Step Card

    @ViewBuilder
    private func stepCard<Content: View>(
        number: Int,
        title: String,
        isDone: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isDone ? Color.green : Color.accentColor)
                            .frame(width: 28, height: 28)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(number)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(isDone ? "Done" : "Next")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isDone ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.15))
                        .foregroundStyle(isDone ? .green : .accentColor)
                        .clipShape(Capsule())
                }
                content()
            }
        }
    }

    // MARK: - AI Explanation

    private var aiExplanationBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What happens next:")
                .font(.subheadline.bold())
            Group {
                Text("• AI reads all evidence from both parties")
                Text("• Analyzes claims against deal terms")
                Text("• Issues a verdict in 10–30 seconds")
                Text("• Decision is RELEASE (to seller) or REFUND (to buyer)")
                Text("• The verdict is final and binding")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
