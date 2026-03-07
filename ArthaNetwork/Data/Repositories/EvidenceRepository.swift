import Foundation

struct EvidenceRepository {
    private let api = APIClient.shared

    func fetchEvidence(dealId: String) async throws -> EvidencePage {
        try await api.get(APIEndpoints.evidence(dealId))
    }

    func submitTextEvidence(
        dealId: String,
        description: String,
        walletAddress: String,
        type: String
    ) async throws -> Evidence {
        let body = SubmitEvidenceRequest(
            description: description,
            walletAddress: walletAddress,
            type: type
        )
        return try await api.post(APIEndpoints.evidence(dealId), body: body)
    }

    func uploadFileEvidence(
        dealId: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        walletAddress: String
    ) async throws -> Evidence {
        try await api.upload(
            APIEndpoints.evidenceUpload(dealId),
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            queryItems: [.init(name: "wallet_address", value: walletAddress)]
        )
    }

    func requestArbitration(dealId: String) async throws -> ArbitrationResponse {
        try await api.post(APIEndpoints.arbitrate(dealId), body: EmptyBody())
    }

    func fetchResolution(dealId: String) async throws -> Resolution {
        try await api.get(APIEndpoints.resolution(dealId))
    }
}
