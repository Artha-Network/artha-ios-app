import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        Form {
            // MARK: - Profile completeness
            if !appState.isProfileComplete {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Profile Incomplete", systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 6) {
                            completenessRow(
                                label: "Display name",
                                isDone: !(appState.currentUser?.displayName ?? "").isEmpty
                            )
                            completenessRow(
                                label: "Email address",
                                isDone: !(appState.currentUser?.emailAddress ?? "").isEmpty
                            )
                        }

                        Text("Both fields are required to create and join escrow deals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    Label("Profile Complete", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.bold())
                }
            }

            Section("Wallet") {
                if let wallet = appState.currentUser?.walletAddress {
                    HStack {
                        Text("Address")
                        Spacer()
                        Text(wallet.prefix(6) + "..." + wallet.suffix(4))
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                }
            }

            Section("Profile") {
                TextField("Display Name", text: $viewModel.displayName)
                TextField("Email Address", text: $viewModel.emailAddress)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            Section("Reputation") {
                HStack {
                    Text("Score")
                    Spacer()
                    Text("\(appState.currentUser?.reputationScore ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Save Profile") {
                    Task {
                        if let updatedUser = await viewModel.saveProfile() {
                            appState.currentUser = updatedUser
                        }
                    }
                }
                .disabled(viewModel.isLoading)

                if viewModel.isSaved {
                    Label("Saved successfully", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }

            Section {
                Button("Disconnect Wallet", role: .destructive) {
                    Task { await viewModel.logout(wallet: walletManager, appState: appState) }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("Profile")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            // Pre-populate immediately from the cached session so the form is never blank.
            if let user = appState.currentUser {
                viewModel.displayName = user.displayName ?? ""
                viewModel.emailAddress = user.emailAddress ?? ""
            }
            // Refresh from server in case fields changed since login.
            await viewModel.loadProfile()
        }
    }

    private func completenessRow(label: String, isDone: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isDone ? .green : .red)
                .font(.caption)
            Text(label)
                .font(.caption)
                .foregroundStyle(isDone ? .secondary : .primary)
        }
    }
}
