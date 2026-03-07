import Foundation
import Observation

@Observable
final class Step3ViewModel {
    var isLoading = false
    var error: String?
    var currentStep: InitiateStep?

    enum InitiateStep: Equatable {
        case preparingTransaction
        case waitingForSignature
        case submittingToNetwork
        case confirming

        var statusText: String {
            switch self {
            case .preparingTransaction: return "Preparing transaction\u{2026}"
            case .waitingForSignature:  return "Waiting for Phantom to sign\u{2026}"
            case .submittingToNetwork:  return "Submitting to Solana\u{2026}"
            case .confirming:           return "Confirming with server\u{2026}"
            }
        }

        var hintText: String? {
            switch self {
            case .waitingForSignature:
                return "Return to this app after signing in Phantom."
            default:
                return nil
            }
        }
    }

    /// `wallet` is the shared WalletManager from the view's @Environment — never create a local instance.
    func createEscrow(draft: EscrowDraft, coordinator: EscrowFlowCoordinator, wallet: WalletManager) async {
        isLoading = true
        error = nil
        defer {
            isLoading = false
            currentStep = nil
        }
        do {
            currentStep = .preparingTransaction
            let useCase = EscrowActionUseCase(wallet: wallet)
            // EscrowActionUseCase.initiate calls wallet.signTransaction() which suspends until
            // Phantom returns. Prime the step so the UI updates before the deeplink fires.
            currentStep = .waitingForSignature
            let dealId = try await useCase.initiate(draft: draft)
            coordinator.complete(dealId: dealId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Cancels any in-flight wallet signing by disconnecting.
    /// `wallet.disconnect()` resumes all pending continuations with `.userCancelled`.
    func cancel(wallet: WalletManager) {
        wallet.disconnect()
    }
}
