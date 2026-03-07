import Foundation
import Observation

/// Persists the multi-step escrow creation wizard state to UserDefaults.
/// Mirrors the web-app's localStorage-based approach for surviving app restarts.
@Observable
final class EscrowFlowCache {
    var draft: EscrowDraft?

    init() {
        load()
    }

    func save() {
        guard let draft else {
            UserDefaults.standard.clearEscrowFlow()
            return
        }
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.escrowFlowData = data
        }
    }

    func load() {
        guard let data = UserDefaults.standard.escrowFlowData else { return }
        self.draft = try? JSONDecoder().decode(EscrowDraft.self, from: data)
    }

    func clear() {
        draft = nil
        UserDefaults.standard.clearEscrowFlow()
    }
}

/// Represents the in-progress escrow deal being created across wizard steps.
struct EscrowDraft: Codable {
    // Step 1 - Deal Details
    var title: String = ""
    var description: String = ""
    var counterpartyWallet: String = ""
    var counterpartyEmail: String = ""
    var amount: Double = 0
    var fundingDeadline: Date = Date().addingTimeInterval(3600)
    var completionDeadline: Date = Date().addingTimeInterval(86400)
    var disputeDeadline: Date = Date().addingTimeInterval(172800)
    var vin: String?

    // Car-specific metadata
    var carYear: Int?
    var carMake: String?
    var carModel: String?
    var deliveryType: String?
    var hasTitleInHand: Bool?

    // Step 2 - AI Contract
    var generatedContract: String?

    // Step 3 - Review (populated after initiate)
    var dealId: String?
}
