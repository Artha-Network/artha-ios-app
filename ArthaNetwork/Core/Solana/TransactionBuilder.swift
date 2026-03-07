import Foundation

/// Handles decoding server-provided transactions and coordinating signing + submission.
enum TransactionBuilder {

    /// Decodes a base64-encoded transaction message from the actions-server,
    /// sends it to the wallet for signing, then submits to Solana RPC.
    ///
    /// Flow:
    /// 1. Receive `txMessageBase64` from actions-server
    /// 2. Decode base64 -> raw transaction bytes
    /// 3. Send to wallet (Phantom/Solflare) for signing via deeplink
    /// 4. Receive signed transaction back via app URL scheme callback
    /// 5. Submit signed transaction to Solana RPC
    /// 6. Return transaction signature
    static func signAndSend(
        txMessageBase64: String,
        using wallet: WalletManager
    ) async throws -> String {
        guard let txData = Data(base64Encoded: txMessageBase64) else {
            throw TransactionError.invalidBase64
        }
        // Triggers Phantom deeplink; suspends until artha://signedTransaction callback arrives.
        let signedTx = try await wallet.signTransaction(txData)
        let signature = try await SolanaClient.shared.sendTransaction(
            serializedTransaction: signedTx.base64EncodedString()
        )
        return signature
    }

    /// POSTs the confirmed transaction signature to the actions-server.
    static func confirmWithServer(
        dealId: String,
        txSig: String,
        action: String,
        actorWallet: String
    ) async throws {
        let body = ConfirmRequest(
            dealId: dealId,
            txSig: txSig,
            action: action,
            actorWallet: actorWallet
        )
        let _: ConfirmResponse = try await APIClient.shared.post(
            APIEndpoints.actionConfirm,
            body: body
        )
    }
}

enum TransactionError: Error, LocalizedError {
    case invalidBase64
    case signingFailed(String)
    case submissionFailed(String)
    case confirmationTimeout

    var errorDescription: String? {
        switch self {
        case .invalidBase64: return "Invalid transaction data"
        case .signingFailed(let msg): return "Signing failed: \(msg)"
        case .submissionFailed(let msg): return "Transaction failed: \(msg)"
        case .confirmationTimeout: return "Transaction confirmation timed out"
        }
    }
}

private struct ConfirmRequest: Encodable {
    let dealId: String
    let txSig: String
    let action: String
    let actorWallet: String
}

private struct ConfirmResponse: Decodable {}
