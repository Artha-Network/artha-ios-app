import SwiftUI

struct Step2_ContractView: View {
    let coordinator: EscrowFlowCoordinator
    @State private var viewModel = Step2ViewModel()

    var body: some View {
        Form {
            if let contract = viewModel.contract {
                Section {
                    // Source badge
                    if let source = viewModel.source {
                        HStack(spacing: 4) {
                            Image(systemName: source == "ai" ? "sparkles" : "doc.text")
                                .font(.caption)
                            Text(source == "ai" ? "AI-Generated" : "Template")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(source == "ai" ? .blue : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    MarkdownView(markdown: contract, font: .caption)
                        .frame(minHeight: 200)

                    Button("Regenerate") {
                        Task { await viewModel.generateContract(draft: coordinator.cache.draft) }
                    }
                    .disabled(viewModel.isLoading)
                    .font(.subheadline)
                } header: {
                    Text("Contract")
                }

                if let questions = viewModel.questions, !questions.isEmpty {
                    Section("Compliance Questions") {
                        ForEach(questions, id: \.self) { question in
                            Label(question, systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = viewModel.error {
                    Section {
                        ErrorBanner(message: error)
                    }
                }

            } else {
                Section {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView("Generating contract with AI\u{2026}")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else if let error = viewModel.error {
                            ErrorBanner(message: error)
                            Button("Retry") {
                                Task { await viewModel.generateContract(draft: coordinator.cache.draft) }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                Button("Continue to Review") {
                    if let contract = viewModel.contract {
                        coordinator.cache.draft?.generatedContract = contract
                        coordinator.cache.save()
                        coordinator.goToStep3()
                    }
                }
                .disabled(viewModel.contract == nil || viewModel.isLoading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Step 2 of 3 — Contract")
        .task {
            if viewModel.contract == nil {
                await viewModel.generateContract(draft: coordinator.cache.draft)
            }
        }
    }
}
