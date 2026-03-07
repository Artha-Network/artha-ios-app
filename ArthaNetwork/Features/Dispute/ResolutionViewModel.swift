import Foundation
import Observation

@Observable
final class ResolutionViewModel {
    var resolution: Resolution?
    var deal: Deal?
    var isLoading = false
    var currentAction: ActionStep?
    var error: String?
    var executeError: String?

    enum ActionStep: Equatable {
        case waitingForSignature
        case confirming

        var statusText: String {
            switch self {
            case .waitingForSignature: return "Waiting for Phantom to sign…"
            case .confirming: return "Confirming on-chain…"
            }
        }

        var hintText: String? {
            switch self {
            case .waitingForSignature: return "Return to this app after signing in Phantom."
            case .confirming: return nil
            }
        }
    }

    private let evidenceUseCase = EvidenceUseCase()
    private let dealUseCase = DealUseCase()

    func load(dealId: String) async {
        isLoading = true
        async let resolutionResult = evidenceUseCase.fetchResolution(dealId: dealId)
        async let dealResult = dealUseCase.fetchDeal(id: dealId)
        do {
            (resolution, deal) = try await (resolutionResult, dealResult)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// `wallet` is the shared WalletManager from the view's @Environment — never create a local instance.
    func executeResolution(dealId: String, walletAddress: String, wallet: WalletManager) async {
        guard let resolution else { return }
        executeError = nil
        currentAction = .waitingForSignature
        defer { currentAction = nil }
        do {
            let useCase = EscrowActionUseCase(wallet: wallet)
            if resolution.outcome == "RELEASE" {
                try await useCase.release(dealId: dealId)
            } else {
                try await useCase.refund(dealId: dealId)
            }
            // Reload deal to reflect terminal state
            deal = try await dealUseCase.fetchDeal(id: dealId)
        } catch {
            executeError = error.localizedDescription
        }
    }

    func cancelExecution(wallet: WalletManager) {
        wallet.disconnect()
    }
}
