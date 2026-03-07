import Foundation

struct SubmitEvidenceRequest: Encodable {
    let description: String
    let walletAddress: String
    let type: String
}
