import Foundation

/// Orchestrates escrow actions: initiate, fund, release, refund, dispute.
/// Each action follows the pattern: call API -> sign TX -> submit -> confirm.
struct EscrowActionUseCase {
    private let dealRepo: DealRepository
    private let wallet: WalletManager

    init(dealRepo: DealRepository = .init(), wallet: WalletManager) {
        self.dealRepo = dealRepo
        self.wallet = wallet
    }

    /// Create a new escrow deal and sign the initiation transaction.
    func initiate(draft: EscrowDraft) async throws -> String {
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }

        let response = try await dealRepo.initiateEscrow(
            sellerWallet: pubkey,
            buyerWallet: draft.counterpartyWallet,
            amount: draft.amount,
            title: draft.title,
            description: draft.description,
            buyerEmail: draft.counterpartyEmail,
            contract: draft.generatedContract,
            fundingDeadline: draft.fundingDeadline,
            completionDeadline: draft.completionDeadline,
            disputeDeadline: draft.disputeDeadline,
            vin: draft.vin
        )

        let txSig = try await TransactionBuilder.signAndSend(
            txMessageBase64: response.txMessageBase64,
            using: wallet
        )

        try await TransactionBuilder.confirmWithServer(
            dealId: response.dealId,
            txSig: txSig,
            action: "INITIATE",
            actorWallet: pubkey
        )

        return response.dealId
    }

    /// Fund an existing escrow deal.
    func fund(dealId: String, amount: Double) async throws {
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }

        let response = try await dealRepo.fundEscrow(dealId: dealId, buyerWallet: pubkey, amount: amount)
        let txSig = try await TransactionBuilder.signAndSend(
            txMessageBase64: response.txMessageBase64,
            using: wallet
        )
        try await TransactionBuilder.confirmWithServer(
            dealId: dealId, txSig: txSig, action: "FUND", actorWallet: pubkey
        )
    }

    /// Release funds to seller.
    func release(dealId: String) async throws {
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }

        let response = try await dealRepo.releaseEscrow(dealId: dealId, sellerWallet: pubkey)
        let txSig = try await TransactionBuilder.signAndSend(
            txMessageBase64: response.txMessageBase64,
            using: wallet
        )
        try await TransactionBuilder.confirmWithServer(
            dealId: dealId, txSig: txSig, action: "RELEASE", actorWallet: pubkey
        )
    }

    /// Refund funds to buyer.
    func refund(dealId: String) async throws {
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }

        let response = try await dealRepo.refundEscrow(dealId: dealId, buyerWallet: pubkey)
        let txSig = try await TransactionBuilder.signAndSend(
            txMessageBase64: response.txMessageBase64,
            using: wallet
        )
        try await TransactionBuilder.confirmWithServer(
            dealId: dealId, txSig: txSig, action: "REFUND", actorWallet: pubkey
        )
    }

    /// Open a dispute on a funded deal.
    func openDispute(dealId: String) async throws {
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }

        let response = try await dealRepo.openDispute(dealId: dealId, callerWallet: pubkey)
        let txSig = try await TransactionBuilder.signAndSend(
            txMessageBase64: response.txMessageBase64,
            using: wallet
        )
        try await TransactionBuilder.confirmWithServer(
            dealId: dealId, txSig: txSig, action: "OPEN_DISPUTE", actorWallet: pubkey
        )
    }
}
