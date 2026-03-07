import SwiftUI

struct DisputeView: View {
    let dealId: String
    @Environment(AppRouter.self) private var router
    @State private var viewModel = DisputeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status header
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Dispute Active")
                                .font(.headline)
                        }
                        Text("Submit evidence to support your claim. The AI arbiter will review all evidence from both parties.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Evidence section
                GroupBox("Evidence Submitted") {
                    if viewModel.evidence.isEmpty {
                        Text("No evidence yet. Submit yours below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.evidence) { item in
                            EvidenceRowView(evidence: item)
                        }
                    }
                }
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    NavigationLink(value: AppRouter.Destination.evidence(dealId)) {
                        Label("Submit Evidence", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if viewModel.canRequestArbitration {
                        Button {
                            Task { await viewModel.requestArbitration() }
                        } label: {
                            Label("Request AI Arbitration", systemImage: "brain")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.purple)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal)

                if let error = viewModel.error {
                    ErrorBanner(message: error)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Dispute")
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Requesting arbitration…")
            }
        }
        .onAppear {
            // Reload evidence every time this view appears so the list
            // stays fresh after returning from EvidenceListView.
            Task { await viewModel.loadEvidence(dealId: dealId) }
        }
        .onChange(of: viewModel.arbitrationResult != nil) { _, hasResult in
            if hasResult {
                router.navigateToResolution(dealId)
            }
        }
    }
}
