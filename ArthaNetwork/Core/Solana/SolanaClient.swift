import Foundation

// MARK: - Solana Errors

enum SolanaError: Error, LocalizedError {
    case httpError(Int)
    case rpcError(code: Int, message: String)
    case emptyResult
    case transactionNotConfirmed

    var errorDescription: String? {
        switch self {
        case .httpError(let status):
            return "Solana RPC HTTP error (status \(status))"
        case .rpcError(_, let message):
            return "Solana RPC error: \(message)"
        case .emptyResult:
            return "Solana RPC returned an empty result"
        case .transactionNotConfirmed:
            return "Transaction was not confirmed within the timeout window"
        }
    }
}

// MARK: - RPC Response Types

private struct RPCResponse<T: Decodable>: Decodable {
    let result: T?
    let error: RPCErrorBody?
}

private struct RPCErrorBody: Decodable {
    let code: Int
    let message: String
}

/// Wrapper used for `getSignatureStatuses` — result is an object with a `value` array.
private struct SignatureStatusesResult: Decodable {
    let value: [SignatureStatus?]
}

private struct SignatureStatus: Decodable {
    let confirmationStatus: String?
    let err: AnyCodable?
}

/// Minimal AnyCodable to absorb the polymorphic `err` field without crashing.
private struct AnyCodable: Decodable {
    init(from decoder: Decoder) throws {
        // We only care whether err is null or non-null, so we don't need to decode the value.
        _ = try? decoder.singleValueContainer()
    }
}

/// Response shape for `getTokenAccountsByOwner` with jsonParsed encoding.
private struct TokenAccountsResult: Decodable {
    let value: [TokenAccountEntry]
}

private struct TokenAccountEntry: Decodable {
    let account: TokenAccountData
}

private struct TokenAccountData: Decodable {
    let data: ParsedTokenData
}

private struct ParsedTokenData: Decodable {
    let parsed: ParsedTokenInfo
}

private struct ParsedTokenInfo: Decodable {
    let info: TokenInfo
}

private struct TokenInfo: Decodable {
    let tokenAmount: TokenAmount
}

private struct TokenAmount: Decodable {
    let uiAmount: Double?
    let amount: String
    let decimals: Int
}

// MARK: - SolanaClient

/// Minimal Solana JSON-RPC client for transaction submission and confirmation polling.
actor SolanaClient {
    static let shared = SolanaClient()

    private let session: URLSession
    private var rpcURL: URL {
        URL(string: AppConfiguration.solanaRPCURL)!
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Balance Queries (future)

    /// Fetch SOL balance for a wallet address (in lamports).
    func getBalance(pubkey: String) async throws -> UInt64 {
        let data = try await rpcRequest(method: "getBalance", params: [pubkey])
        let response = try JSONDecoder().decode(RPCResponse<UInt64>.self, from: data)
        if let err = response.error { throw SolanaError.rpcError(code: err.code, message: err.message) }
        return response.result ?? 0
    }

    /// Fetch USDC token balance for a wallet address.
    /// Uses `getTokenAccountsByOwner` RPC filtered by the configured USDC mint.
    func getUSDCBalance(pubkey: String) async throws -> Double {
        let params: [Any] = [
            pubkey,
            ["mint": AppConfiguration.usdcMint] as [String: String],
            ["encoding": "jsonParsed"] as [String: String]
        ]
        let data = try await rpcRequest(method: "getTokenAccountsByOwner", params: params)
        let response = try JSONDecoder().decode(RPCResponse<TokenAccountsResult>.self, from: data)
        if let err = response.error {
            throw SolanaError.rpcError(code: err.code, message: err.message)
        }
        guard let accounts = response.result?.value, let first = accounts.first else {
            return 0
        }
        return first.account.data.parsed.info.tokenAmount.uiAmount ?? 0
    }

    // MARK: - Transaction Submission

    /// Sends a signed, base64-encoded serialized transaction to the Solana network.
    /// Returns the transaction signature string on success.
    func sendTransaction(serializedTransaction: String) async throws -> String {
        let params: [Any] = [
            serializedTransaction,
            ["encoding": "base64", "preflightCommitment": "confirmed"] as [String: String]
        ]
        let data = try await rpcRequest(method: "sendTransaction", params: params)
        let response = try JSONDecoder().decode(RPCResponse<String>.self, from: data)
        if let err = response.error {
            throw SolanaError.rpcError(code: err.code, message: err.message)
        }
        guard let signature = response.result else {
            throw SolanaError.emptyResult
        }
        return signature
    }

    // MARK: - Transaction Confirmation

    /// Polls `getSignatureStatuses` until the transaction reaches "confirmed" or "finalized".
    /// Polls every 2 seconds for up to 60 seconds, then throws `.transactionNotConfirmed`.
    func confirmTransaction(signature: String) async throws -> Bool {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { throw CancellationError() }

            let data = try await rpcRequest(
                method: "getSignatureStatuses",
                params: [[signature], ["searchTransactionHistory": true] as [String: Bool]]
            )
            let response = try JSONDecoder().decode(RPCResponse<SignatureStatusesResult>.self, from: data)

            if let err = response.error {
                throw SolanaError.rpcError(code: err.code, message: err.message)
            }
            if let status = response.result?.value.first ?? nil {
                // `err` being non-nil means the transaction failed on-chain.
                if status.err != nil {
                    throw SolanaError.rpcError(code: 0, message: "Transaction failed on-chain")
                }
                let conf = status.confirmationStatus ?? ""
                if conf == "confirmed" || conf == "finalized" {
                    return true
                }
            }
        }
        throw SolanaError.transactionNotConfirmed
    }

    // MARK: - Private: JSON-RPC Transport

    private func rpcRequest(method: String, params: [Any]) async throws -> Data {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SolanaError.httpError(http.statusCode)
        }
        return data
    }
}
