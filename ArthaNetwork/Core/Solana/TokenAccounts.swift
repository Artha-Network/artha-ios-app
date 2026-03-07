import Foundation

/// Helpers for querying SPL token balances on Solana.
enum TokenAccounts {

    /// Fetch USDC balance for a given wallet public key.
    /// Returns the balance in human-readable USDC (6 decimal places).
    static func fetchUSDCBalance(for pubkey: String) async throws -> Double {
        try await SolanaClient.shared.getUSDCBalance(pubkey: pubkey)
    }

    /// Fetch SOL balance for a given wallet public key.
    /// Returns the balance in SOL (not lamports).
    static func fetchSOLBalance(for pubkey: String) async throws -> Double {
        let lamports = try await SolanaClient.shared.getBalance(pubkey: pubkey)
        return Double(lamports) / 1_000_000_000.0
    }

    /// Check if a wallet has enough USDC to fund an escrow.
    static func hasSufficientUSDC(pubkey: String, requiredAmount: Double) async throws -> Bool {
        let balance = try await fetchUSDCBalance(for: pubkey)
        return balance >= requiredAmount
    }
}
