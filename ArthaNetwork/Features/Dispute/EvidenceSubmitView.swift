import SwiftUI

struct EvidenceSubmitView: View {
    let dealId: String
    let walletAddress: String
    var onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var evidenceType = "OTHER"
    @State private var isLoading = false
    @State private var error: String?

    private let evidenceTypes = ["DELIVERY_PROOF", "PAYMENT_PROOF", "COMMUNICATION", "DAMAGE_PROOF", "OTHER"]
    private let evidenceUseCase = EvidenceUseCase()

    var body: some View {
        NavigationStack {
            Form {
                Section("Evidence Type") {
                    Picker("Type", selection: $evidenceType) {
                        ForEach(evidenceTypes, id: \.self) { type in
                            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                }

                if let error {
                    Section {
                        ErrorBanner(message: error)
                    }
                }
            }
            .navigationTitle("Submit Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(description.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private func submit() async {
        isLoading = true
        error = nil
        do {
            _ = try await evidenceUseCase.submitTextEvidence(
                dealId: dealId,
                description: description,
                walletAddress: walletAddress,
                type: evidenceType
            )
            onSubmitted()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
