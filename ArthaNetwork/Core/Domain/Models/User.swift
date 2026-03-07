import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: String
    let walletAddress: String
    var displayName: String?
    var emailAddress: String?
    var reputationScore: Int?
    var kycLevel: String?
    let createdAt: Date?
    let updatedAt: Date?
}
