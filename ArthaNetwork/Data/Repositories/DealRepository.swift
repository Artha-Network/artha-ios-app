import Foundation

struct DealRepository {
    private let api = APIClient.shared

    func fetchDeals(wallet: String, offset: Int, limit: Int) async throws -> DealsPage {
        try await api.get(APIEndpoints.deals, queryItems: [
            .init(name: "wallet_address", value: wallet),
            .init(name: "offset", value: String(offset)),
            .init(name: "limit", value: String(limit))
        ])
    }

    func fetchDeal(id: String) async throws -> Deal {
        try await api.get(APIEndpoints.deal(id))
    }

    func deleteDeal(id: String) async throws {
        try await api.delete(APIEndpoints.deal(id))
    }

    func fetchRecentEvents(wallet: String, limit: Int) async throws -> [DealEventRow] {
        try await api.get(APIEndpoints.recentEvents, queryItems: [
            .init(name: "wallet_address", value: wallet),
            .init(name: "limit", value: String(limit))
        ])
    }

    // MARK: - Escrow Actions

    func initiateEscrow(
        sellerWallet: String,
        buyerWallet: String,
        amount: Double,
        title: String,
        description: String,
        buyerEmail: String,
        contract: String?,
        fundingDeadline: Date,
        completionDeadline: Date,
        disputeDeadline: Date,
        vin: String?
    ) async throws -> ActionResponse {
        let body = InitiateRequest(
            sellerWallet: sellerWallet,
            buyerWallet: buyerWallet,
            amount: amount,
            feeBps: 50,
            deliverBy: Int(completionDeadline.timeIntervalSince1970),
            disputeDeadline: Int(disputeDeadline.timeIntervalSince1970),
            description: description,
            title: title,
            buyerEmail: buyerEmail,
            contract: contract,
            payer: sellerWallet,
            vin: vin
        )
        return try await api.post(APIEndpoints.actionInitiate, body: body)
    }

    func fundEscrow(dealId: String, buyerWallet: String, amount: Double) async throws -> ActionResponse {
        let body = FundRequest(dealId: dealId, buyerWallet: buyerWallet, amount: amount)
        return try await api.post(APIEndpoints.actionFund, body: body)
    }

    func releaseEscrow(dealId: String, sellerWallet: String) async throws -> ActionResponse {
        let body = ReleaseRequest(dealId: dealId, sellerWallet: sellerWallet)
        return try await api.post(APIEndpoints.actionRelease, body: body)
    }

    func refundEscrow(dealId: String, buyerWallet: String) async throws -> ActionResponse {
        let body = RefundRequest(dealId: dealId, buyerWallet: buyerWallet)
        return try await api.post(APIEndpoints.actionRefund, body: body)
    }

    func openDispute(dealId: String, callerWallet: String) async throws -> ActionResponse {
        let body = DisputeRequest(dealId: dealId, callerWallet: callerWallet)
        return try await api.post(APIEndpoints.actionOpenDispute, body: body)
    }

    // MARK: - AI

    func generateContract(
        title: String,
        role: String,
        counterparty: String,
        amount: Double,
        description: String,
        deliveryDeadline: String,
        disputeDeadline: String
    ) async throws -> ContractGenerationResponse {
        let body = GenerateContractRequest(
            title: title,
            role: role,
            counterparty: counterparty,
            amount: amount,
            description: description,
            deliveryDeadline: deliveryDeadline,
            disputeDeadline: disputeDeadline
        )
        return try await api.post(APIEndpoints.generateContract, body: body)
    }

    func fetchCarEscrowPlan(input: CarEscrowPlanInput) async throws -> CarEscrowPlan {
        try await api.post(APIEndpoints.carEscrowPlan, body: input)
    }
}
