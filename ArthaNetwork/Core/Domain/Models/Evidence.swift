import Foundation

struct Evidence: Codable, Identifiable, Sendable {
    let id: String
    let dealId: String
    let submittedById: String?
    let cid: String?
    let description: String?
    let mimeType: String?
    let type: String?
    let createdAt: Date?
}

struct EvidencePage: Codable, Sendable {
    let evidence: [Evidence]
    let total: Int
}
