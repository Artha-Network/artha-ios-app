import Foundation
import Observation

@Observable
final class ResolutionViewModel {
    var resolution: Resolution?
    var deal: Deal?
    var isLoading = false
    var isPolling = false
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
    private var pollingTask: Task<Void, Never>?

    func load(dealId: String) async {
        isLoading = true
        async let resolutionResult = evidenceUseCase.fetchResolution(dealId: dealId)
        async let dealResult = dealUseCase.fetchDeal(id: dealId)
        do {
            let (res, d) = try await (resolutionResult, dealResult)
            resolution = res
            deal = d
        } catch {
            // Resolution may 404 if not yet issued — that's expected, not an error.
            if let apiError = error as? APIError, case .httpError(statusCode: let code) = apiError, code == 404 {
                // No resolution yet — start polling.
                do { deal = try await dealUseCase.fetchDeal(id: dealId) } catch {}
            } else {
                self.error = error.localizedDescription
            }
        }
        isLoading = false

        // If no resolution yet and deal is DISPUTED, poll for it.
        if resolution == nil, deal?.status == .DISPUTED {
            startPolling(dealId: dealId)
        }
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
            deal = try await dealUseCase.fetchDeal(id: dealId)
        } catch {
            executeError = error.localizedDescription
        }
    }

    func cancelExecution(wallet: WalletManager) {
        wallet.disconnect()
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    // MARK: - Private

    private func startPolling(dealId: String) {
        pollingTask?.cancel()
        isPolling = true
        pollingTask = Task {
            // Poll every 5 seconds for up to 2 minutes.
            for _ in 0..<24 {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                do {
                    let res = try await evidenceUseCase.fetchResolution(dealId: dealId)
                    resolution = res
                    // Also refresh deal to get updated status.
                    deal = try await dealUseCase.fetchDeal(id: dealId)
                    isPolling = false
                    return
                } catch {
                    // 404 = not ready yet, keep polling. Other errors = stop.
                    if let apiError = error as? APIError, case .httpError(statusCode: let code) = apiError, code == 404 {
                        continue
                    } else {
                        break
                    }
                }
            }
            isPolling = false
        }
    }
}
