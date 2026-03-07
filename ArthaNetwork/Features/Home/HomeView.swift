import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(WalletManager.self) private var walletManager
    @State private var showWalletConnect = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Hero Section
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("Artha Network")
                        .font(.largeTitle.bold())

                    Text("Secure peer-to-peer escrow powered by Solana")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "shield.checkmark", title: "Non-Custodial", subtitle: "Funds secured in smart contracts")
                    FeatureRow(icon: "brain", title: "AI Arbitration", subtitle: "Fair dispute resolution powered by AI")
                    FeatureRow(icon: "dollarsign.circle", title: "USDC Payments", subtitle: "Stable, low-cost transactions")
                }
                .padding(.horizontal)

                Spacer()

                // CTA
                Button {
                    showWalletConnect = true
                } label: {
                    Text("Connect Wallet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showWalletConnect) {
                WalletConnectView(wallet: walletManager)
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
