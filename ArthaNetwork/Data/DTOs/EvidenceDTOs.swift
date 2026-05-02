import Foundation

struct SubmitEvidenceRequest: Encodable {
    let description: String
    let walletAddress: String
    let type: String
}

/// Body for POST /api/deals/:id/escalate
/// The server reads `wallet_address` (snake_case) for this endpoint.
struct EscalateRequest: Encodable {
    let walletAddress: String
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case walletAddress = "wallet_address"
        case reason
    }
}
