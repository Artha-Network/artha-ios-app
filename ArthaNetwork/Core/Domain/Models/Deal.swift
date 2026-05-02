import Foundation

struct Deal: Codable, Identifiable, Sendable {
    let id: String
    let sellerId: String?
    let buyerId: String?
    let sellerWallet: String
    let buyerWallet: String
    let priceUsd: Double
    let status: DealStatus
    let title: String?
    let description: String?
    let onchainAddress: String?
    let feeBps: Int?
    let deliverDeadline: Date?
    let disputeDeadline: Date?
    let vin: String?
    let contract: String?
    let metadata: DealMetadata?
    let fundedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    // Set by the counterparty when they agree to the deal terms.
    let counterpartyAcceptedAt: Date?
    // The wallet that created (initiated) the deal on-chain.
    let createdByWallet: String?

    // Populated on detail fetch
    let seller: User?
    let buyer: User?
    let onchainEvents: [OnchainEvent]?
    let aiResolution: Resolution?
}

struct DealMetadata: Codable, Sendable {
    let carYear: Int?
    let carMake: String?
    let carModel: String?
    let deliveryType: String?
}

struct OnchainEvent: Codable, Identifiable, Sendable {
    let id: String
    let dealId: String
    let txSig: String
    let instruction: String
    let amount: Double?
    let createdAt: Date?
}

struct DealEventRow: Codable, Identifiable, Sendable {
    let id: String
    let dealId: String
    let txSig: String
    let instruction: String
    let createdAt: Date?
}

struct DealsPage: Codable, Sendable {
    let deals: [Deal]
    let total: Int
}
