import SwiftUI

/// Owns the EscrowFlowCoordinator for the create-deal wizard.
/// All navigation is driven by coordinator.navigationPath bound to a single NavigationStack.
struct EscrowTabView: View {
    @State private var coordinator = EscrowFlowCoordinator()
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.navigationPath) {
            Group {
                if appState.isProfileComplete {
                    Step1_DealDetailsView(coordinator: self.coordinator)
                } else {
                    profileRequiredView
                }
            }
            .navigationDestination(for: EscrowStep.self) { step in
                switch step {
                case .step2:
                    Step2_ContractView(coordinator: self.coordinator)
                case .step3:
                    Step3_ReviewFundView(coordinator: self.coordinator)
                case .confirmation(let dealId):
                    EscrowConfirmationView(dealId: dealId) {
                        coordinator.reset()
                        router.navigateToDeal(dealId)
                    }
                }
            }
        }
    }

    // MARK: - Profile Required

    private var profileRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Complete Your Profile")
                .font(.title3.bold())

            Text("Please set up your display name and email address before creating an escrow deal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                router.selectedTab = .profile
            } label: {
                Label("Go to Profile", systemImage: "person.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)

            Spacer()
        }
        .navigationTitle("Create Escrow")
    }
}
