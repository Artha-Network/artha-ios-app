import SwiftUI
import Observation

/// Coordinator for the 3-step escrow creation wizard.
/// Owns the shared EscrowFlowCache and drives NavigationStack via a path array.
@Observable
final class EscrowFlowCoordinator {
    var navigationPath: [EscrowStep] = []
    let cache = EscrowFlowCache()

    func goToStep2() {
        navigationPath.append(.step2)
    }

    func goToStep3() {
        navigationPath.append(.step3)
    }

    func complete(dealId: String) {
        cache.clear()
        // Replace path with confirmation so back-stack is clean
        navigationPath = [.confirmation(dealId)]
    }

    func reset() {
        navigationPath = []
        cache.clear()
    }
}

enum EscrowStep: Hashable {
    case step2
    case step3
    case confirmation(String) // associated value: dealId
}
