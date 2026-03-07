import Foundation
import Observation

@Observable
final class Step2ViewModel {
    var contract: String?
    var questions: [String]?
    var isLoading = false
    var error: String?
    var source: String?   // "ai" or "fallback"

    private let dealRepo = DealRepository()

    func generateContract(draft: EscrowDraft?) async {
        guard let draft else { return }
        isLoading = true
        error = nil
        do {
            let isoFormatter = ISO8601DateFormatter()
            let response = try await dealRepo.generateContract(
                title: draft.title,
                role: "seller",       // The deal creator is always the seller in this flow.
                counterparty: draft.counterpartyWallet,
                amount: draft.amount,
                description: draft.description,
                deliveryDeadline: isoFormatter.string(from: draft.completionDeadline),
                disputeDeadline: isoFormatter.string(from: draft.disputeDeadline)
            )
            contract = response.contract
            questions = response.questions
            source = response.source
        } catch {
            // Fall back to a simple template
            self.error = "AI contract unavailable — using template"
            contract = generateFallbackContract(draft: draft)
        }
        isLoading = false
    }

    private func generateFallbackContract(draft: EscrowDraft) -> String {
        """
        # Escrow Agreement

        **Title:** \(draft.title)
        **Amount:** $\(draft.amount) USDC
        **Description:** \(draft.description)

        This agreement is between the seller and buyer as identified by their Solana wallet addresses.
        Funds will be held in escrow until delivery is confirmed or a dispute is resolved.
        """
    }
}
