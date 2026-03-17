import Foundation

struct Evidence: Codable, Identifiable, Sendable {
    let id: String
    let dealId: String?
    let description: String?
    let mimeType: String?
    /// Wallet address of the submitter.
    let submittedBy: String?
    /// Display name of the submitter (may be nil if profile incomplete).
    let submittedByName: String?
    let submittedAt: Date?
    /// "buyer" or "seller" — computed by the server based on deal participants.
    let role: String?
}

struct EvidencePage: Codable, Sendable {
    let evidence: [Evidence]
    let total: Int
}
