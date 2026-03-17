import Foundation

struct VehicleTitle: Codable, Sendable {
    let vin: String
    let currentOwnerWallet: String
    let titleStatus: String        // "PENDING" or "TRANSFERRED"
    let transferDate: Date?
    let createdAt: Date?
    let updatedAt: Date?

    var isTransferred: Bool {
        titleStatus == "TRANSFERRED"
    }
}
