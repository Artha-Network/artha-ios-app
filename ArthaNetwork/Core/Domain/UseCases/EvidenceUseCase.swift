import Foundation

/// Handles evidence listing, submission, and file upload for disputes.
struct EvidenceUseCase {
    private let evidenceRepo: EvidenceRepository

    init(evidenceRepo: EvidenceRepository = .init()) {
        self.evidenceRepo = evidenceRepo
    }

    func fetchEvidence(dealId: String) async throws -> EvidencePage {
        try await evidenceRepo.fetchEvidence(dealId: dealId)
    }

    func submitTextEvidence(dealId: String, description: String, walletAddress: String, type: String) async throws -> Evidence {
        try await evidenceRepo.submitTextEvidence(
            dealId: dealId,
            description: description,
            walletAddress: walletAddress,
            type: type
        )
    }

    func uploadFileEvidence(dealId: String, fileData: Data, fileName: String, mimeType: String, walletAddress: String) async throws -> Evidence {
        try await evidenceRepo.uploadFileEvidence(
            dealId: dealId,
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            walletAddress: walletAddress
        )
    }

    func requestArbitration(dealId: String) async throws -> ArbitrationResponse {
        try await evidenceRepo.requestArbitration(dealId: dealId)
    }

    func fetchResolution(dealId: String) async throws -> Resolution {
        try await evidenceRepo.fetchResolution(dealId: dealId)
    }
}
