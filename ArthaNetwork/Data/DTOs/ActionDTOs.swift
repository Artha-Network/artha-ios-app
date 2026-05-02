import Foundation

struct InitiateRequest: Encodable {
    let sellerWallet: String
    let buyerWallet: String
    let amount: Double
    let feeBps: Int
    /// Unix timestamp in seconds — server schema is z.number().int().
    let deliverBy: Int
    /// Unix timestamp in seconds — server schema is z.number().int().
    let disputeDeadline: Int
    let description: String
    let title: String
    let buyerEmail: String
    let contract: String?
    let payer: String
    let vin: String?
}

struct FundRequest: Encodable {
    let dealId: String
    let buyerWallet: String
    let amount: Double
}

struct ReleaseRequest: Encodable {
    let dealId: String
    let sellerWallet: String
}

struct RefundRequest: Encodable {
    let dealId: String
    let buyerWallet: String
}

struct DisputeRequest: Encodable {
    let dealId: String
    let callerWallet: String
}

/// Generic single-wallet body used by accept/decline endpoints.
struct WalletRequest: Encodable {
    let walletAddress: String
}

/// Generic success acknowledgement returned by accept/decline.
struct SuccessResponse: Decodable {
    let success: Bool
}

struct ConfirmDeliveryRequest: Encodable {
    let dealId: String
    let buyerWallet: String
}

struct ApproveRefundRequest: Encodable {
    let dealId: String
    let sellerWallet: String
}

struct GenerateContractRequest: Encodable {
    let title: String
    let role: String
    let counterparty: String
    let amount: Double
    let description: String
    let deliveryDeadline: String
    let disputeDeadline: String
}
