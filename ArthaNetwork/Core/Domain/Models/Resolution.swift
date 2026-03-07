import Foundation

struct Resolution: Codable, Sendable {
    let outcome: String           // "RELEASE" or "REFUND"
    let confidence: Double        // 0.0 - 1.0
    let reasonShort: String?
    let rationaleCid: String?
    let violatedRules: [String]?
    let arbiterPubkey: String?
    let signature: String?
    let issuedAt: Date?
    let expiresAt: Date?
}

struct ArbitrationResponse: Codable, Sendable {
    let ticket: ArbitrationTicket
    let arbiterPubkey: String
    let ed25519Signature: String
}

struct ArbitrationTicket: Codable, Sendable {
    let outcome: String
    let confidence: Double
    let rationaleCid: String?
    let expiresAtUtc: String?
}
