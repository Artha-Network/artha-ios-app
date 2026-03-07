import SwiftUI

struct WalletConnectView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AuthViewModel

    init(wallet: WalletManager) {
        _viewModel = State(initialValue: AuthViewModel(wallet: wallet))
    }

    var body: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("Connect Your Wallet")
                    .font(.title2.bold())
                Text("Sign in securely with your Solana wallet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if viewModel.isLoading {
                // In-progress — show which step we're on and a cancel escape hatch.
                AuthProgressView(step: viewModel.currentStep) {
                    viewModel.cancel()
                }
            } else {
                // Idle — show wallet picker.
                WalletPickerView { type in
                    Task {
                        do {
                            let user = try await viewModel.signIn(type: type)
                            appState.setAuthenticated(user: user)
                        } catch {
                            // Error is already surfaced in viewModel.error below.
                        }
                    }
                }
            }

            // Error banner — only shown when not loading so it doesn't flash during retries.
            if let error = viewModel.error, !viewModel.isLoading {
                ErrorBanner(message: error)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 24)
    }
}

// MARK: - Sub-views

/// Shows a step-aware progress indicator and a cancel button.
private struct AuthProgressView: View {
    let step: AuthViewModel.AuthStep?
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)

            VStack(spacing: 6) {
                Text(step?.statusText ?? "Connecting\u{2026}")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)

                if let hint = step?.hintText {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button(role: .destructive, action: onCancel) {
                Text("Cancel")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Renders the wallet selection buttons.
private struct WalletPickerView: View {
    let onSelect: (WalletManager.WalletType) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Phantom — fully supported.
            Button { onSelect(.phantom) } label: {
                WalletRow(
                    name: "Phantom",
                    systemIcon: "circle.hexagongrid.fill",
                    tint: .purple,
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            // Solflare — coming soon. Rendered as non-interactive.
            WalletRow(
                name: "Solflare",
                systemIcon: "sun.max.fill",
                tint: .orange,
                badge: "Coming soon"
            )
            .opacity(0.45)
        }
    }
}

/// Single wallet row used in the picker.
private struct WalletRow: View {
    let name: String
    let systemIcon: String
    let tint: Color
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(name)
                .font(.headline)

            Spacer()

            if let badge {
                Text(badge)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
