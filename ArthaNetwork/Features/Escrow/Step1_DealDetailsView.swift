import SwiftUI

struct Step1_DealDetailsView: View {
    let coordinator: EscrowFlowCoordinator
    @Environment(AppState.self) private var appState
    @State private var viewModel = Step1ViewModel()

    var body: some View {
        Form {
            Section("Deal Info") {
                TextField("Title", text: $viewModel.title)
                TextField("Description (10–1000 chars)", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Counterparty") {
                TextField("Wallet Address", text: $viewModel.counterpartyWallet)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Email Address", text: $viewModel.counterpartyEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Amount") {
                HStack {
                    Text("$")
                    TextField("0.00", value: $viewModel.amount, format: .number)
                        .keyboardType(.decimalPad)
                    Text("USDC")
                        .foregroundStyle(.secondary)
                }
                Text("Minimum $10, maximum $1,000,000")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Deadlines") {
                DatePicker(
                    "Funding Deadline",
                    selection: $viewModel.fundingDeadline,
                    in: Date().addingTimeInterval(3600)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "Delivery Deadline",
                    selection: $viewModel.deliveryDeadline,
                    in: viewModel.fundingDeadline...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "Dispute Deadline",
                    selection: $viewModel.disputeDeadline,
                    in: viewModel.deliveryDeadline...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Vehicle Sale (Optional)") {
                Toggle("This is a car sale", isOn: $viewModel.isCarSale)
                if viewModel.isCarSale {
                    TextField("VIN Number", text: $viewModel.vin)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Year", value: $viewModel.carYear, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Make", text: $viewModel.carMake)
                    TextField("Model", text: $viewModel.carModel)

                    Picker("Delivery Method", selection: $viewModel.deliveryType) {
                        Text("Local Pickup").tag("LOCAL_PICKUP")
                        Text("Shipped").tag("SHIPPED")
                    }

                    Toggle("Title in hand", isOn: $viewModel.hasTitleInHand)
                }
            }

            if viewModel.isCarSale, let plan = viewModel.carEscrowPlan {
                Section("Risk Assessment") {
                    HStack {
                        Text("Risk Level")
                        Spacer()
                        Text(plan.riskLevel.capitalized)
                            .foregroundStyle(
                                plan.riskLevel == "low" ? .green :
                                plan.riskLevel == "medium" ? .orange : .red
                            )
                            .bold()
                    }
                    ForEach(plan.reasons, id: \.self) { reason in
                        Text("• \(reason)")
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

            Section {
                Button("Continue to Contract") {
                    Task { await viewModel.proceed(coordinator: coordinator) }
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Step 1 of 3 — Deal Details")
        .task {
            // Restore any previously saved draft into the form on appear.
            if let draft = coordinator.cache.draft {
                viewModel.loadFromDraft(draft)
            }
        }
        .onChange(of: viewModel.readyForStep2) { _, ready in
            if ready { coordinator.goToStep2() }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay(message: "Checking risk\u{2026}")
            }
        }
    }
}
