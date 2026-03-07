import Foundation
import Observation

@Observable
final class DisputeViewModel {
    var evidence: [Evidence] = []
    var isLoading = false
    var error: String?
    var arbitrationResult: ArbitrationResponse?

    private var dealId: String = ""
    private let evidenceUseCase = EvidenceUseCase()

    var canRequestArbitration: Bool {
        // Enable arbitration once at least one evidence item is submitted
        !evidence.isEmpty && arbitrationResult == nil
    }

    func loadEvidence(dealId: String) async {
        self.dealId = dealId
        isLoading = true
        do {
            let page = try await evidenceUseCase.fetchEvidence(dealId: dealId)
            evidence = page.evidence
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func requestArbitration() async {
        isLoading = true
        error = nil
        do {
            arbitrationResult = try await evidenceUseCase.requestArbitration(dealId: dealId)
            // Setting arbitrationResult triggers DisputeView.onChange → router.navigateToResolution.
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
