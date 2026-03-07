import SwiftUI

/// Owns the EscrowFlowCoordinator for the create-deal wizard.
/// All navigation is driven by coordinator.navigationPath bound to a single NavigationStack.
struct EscrowTabView: View {
    @State private var coordinator = EscrowFlowCoordinator()
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.navigationPath) {
            Step1_DealDetailsView(coordinator: self.coordinator)
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
}
