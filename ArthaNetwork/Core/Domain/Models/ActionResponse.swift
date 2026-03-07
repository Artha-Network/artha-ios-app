import Foundation

/// Response from escrow action endpoints (/actions/initiate, /fund, /release, etc.)
struct ActionResponse: Codable, Sendable {
    let dealId: String
    let txMessageBase64: String
    let latestBlockhash: String?
    let lastValidBlockHeight: Int?
    let feePayer: String?
    let nextClientAction: String?
}

/// Response from the AI contract generation endpoint.
struct ContractGenerationResponse: Codable, Sendable {
    let contract: String
    let questions: [String]?
    let source: String?
}

/// Response from the car escrow risk plan endpoint.
struct CarEscrowPlan: Codable, Sendable {
    let riskScore: Int
    let riskLevel: String
    let reasons: [String]
    let deliveryDeadlineHoursFromNow: Int?
    let disputeWindowHours: [Int]?
    let deliveryDeadlineAtIso: String?
    let disputeWindowEndsAtIso: String?
}
