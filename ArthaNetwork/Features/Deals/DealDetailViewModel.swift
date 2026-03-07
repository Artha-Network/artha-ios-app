import Foundation
import Observation

@Observable
final class DealDetailViewModel {
    var deal: Deal?
    var isLoading = false
    /// Load errors — shown in an alert with Retry / OK.
    var error: String?
    /// Action errors — shown inline near action buttons.
    var actionError: String?
    /// Set to true after a successful delete so the view can dismiss itself.
    var wasDeleted = false
    var currentAction: ActionStep?

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

    private let dealUseCase = DealUseCase()
    private var pollingTask: Task<Void, Never>?

    func loadDeal(id: String) async {
        isLoading = true
        do {
            deal = try await dealUseCase.fetchDeal(id: id)
            startPollingIfNeeded(id: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Poll every 15 seconds for deals in active states (mirrors web-app behavior).
    private func startPollingIfNeeded(id: String) {
        guard let status = deal?.status, !status.isTerminal else { return }
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                if let updated = try? await dealUseCase.fetchDeal(id: id) {
                    deal = updated
                    if updated.status.isTerminal { break }
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
    }

    func deleteDeal(id: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await dealUseCase.deleteDeal(id: id)
            stopPolling()
            wasDeleted = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func fund(dealId: String, wallet: WalletManager) async {
        guard let amount = deal?.priceUsd else { return }
        actionError = nil
        currentAction = .waitingForSignature
        defer { currentAction = nil }
        do {
            try await EscrowActionUseCase(wallet: wallet).fund(dealId: dealId, amount: amount)
            await loadDeal(id: dealId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func release(dealId: String, wallet: WalletManager) async {
        actionError = nil
        currentAction = .waitingForSignature
        defer { currentAction = nil }
        do {
            try await EscrowActionUseCase(wallet: wallet).release(dealId: dealId)
            await loadDeal(id: dealId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func refund(dealId: String, wallet: WalletManager) async {
        actionError = nil
        currentAction = .waitingForSignature
        defer { currentAction = nil }
        do {
            try await EscrowActionUseCase(wallet: wallet).refund(dealId: dealId)
            await loadDeal(id: dealId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func openDispute(dealId: String, wallet: WalletManager) async {
        actionError = nil
        currentAction = .waitingForSignature
        defer { currentAction = nil }
        do {
            try await EscrowActionUseCase(wallet: wallet).openDispute(dealId: dealId)
            await loadDeal(id: dealId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func cancelAction(wallet: WalletManager) {
        wallet.disconnect()
    }
}
