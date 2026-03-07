import Foundation
import Observation

@Observable
final class Step1ViewModel {
    // Form fields — Deal Info
    var title = ""
    var description = ""

    // Form fields — Counterparty
    var counterpartyWallet = ""
    var counterpartyEmail = ""

    // Form fields — Amount
    var amount: Double = 0

    // Form fields — Deadlines
    var fundingDeadline: Date = Date().addingTimeInterval(3600)
    var deliveryDeadline: Date = Date().addingTimeInterval(86400)
    var disputeDeadline: Date = Date().addingTimeInterval(172800)

    // Form fields — Car Sale
    var isCarSale = false
    var vin = ""
    var carYear: Int?
    var carMake = ""
    var carModel = ""
    /// "LOCAL_PICKUP" or "SHIPPED"
    var deliveryType = "LOCAL_PICKUP"
    var hasTitleInHand = true

    /// Risk plan returned by the car escrow planning endpoint.
    var carEscrowPlan: CarEscrowPlan?

    // State
    var isLoading = false
    var error: String?
    /// Set to true after a successful `proceed()`. Always reset to false at the start of
    /// each call so that `onChange(of: readyForStep2)` fires on every tap, including retry.
    var readyForStep2 = false

    private let dealRepo = DealRepository()

    var isValid: Bool {
        !title.isEmpty
            && description.count >= 10
            && !counterpartyWallet.isEmpty
            && !counterpartyEmail.isEmpty
            && amount >= 10
            && amount <= 1_000_000
    }

    /// Populate form fields from a saved draft. Called on Step 1 appear for draft restoration.
    func loadFromDraft(_ draft: EscrowDraft) {
        title = draft.title
        description = draft.description
        counterpartyWallet = draft.counterpartyWallet
        counterpartyEmail = draft.counterpartyEmail
        amount = draft.amount
        fundingDeadline = draft.fundingDeadline
        deliveryDeadline = draft.completionDeadline
        disputeDeadline = draft.disputeDeadline
        if let vin = draft.vin {
            isCarSale = true
            self.vin = vin
            carYear = draft.carYear
            carMake = draft.carMake ?? ""
            carModel = draft.carModel ?? ""
            deliveryType = draft.deliveryType ?? "LOCAL_PICKUP"
            hasTitleInHand = draft.hasTitleInHand ?? true
        }
    }

    func proceed(coordinator: EscrowFlowCoordinator) async {
        guard isValid else { return }
        // Reset before setting so onChange always fires, even when retrying after navigating back.
        readyForStep2 = false
        isLoading = true
        error = nil

        // If car sale, fetch risk plan (non-fatal — failure doesn't block progression).
        if isCarSale && !vin.isEmpty {
            do {
                let input = CarEscrowPlanInput(
                    priceUsd: amount,
                    deliveryType: deliveryType,
                    hasTitleInHand: hasTitleInHand,
                    odometerMiles: nil,
                    year: carYear,
                    isSalvageTitle: false
                )
                carEscrowPlan = try await dealRepo.fetchCarEscrowPlan(input: input)
            } catch {
                // Non-fatal: surface a soft warning but don't block continuation.
                self.error = "Risk assessment unavailable — continuing without it."
            }
        }

        // Save draft to cache for cross-step and cross-session persistence.
        coordinator.cache.draft = EscrowDraft(
            title: title,
            description: description,
            counterpartyWallet: counterpartyWallet,
            counterpartyEmail: counterpartyEmail,
            amount: amount,
            fundingDeadline: fundingDeadline,
            completionDeadline: deliveryDeadline,
            disputeDeadline: disputeDeadline,
            vin: isCarSale ? vin : nil,
            carYear: isCarSale ? carYear : nil,
            carMake: isCarSale ? carMake : nil,
            carModel: isCarSale ? carModel : nil,
            deliveryType: isCarSale ? deliveryType : nil,
            hasTitleInHand: isCarSale ? hasTitleInHand : nil
        )
        coordinator.cache.save()

        isLoading = false
        readyForStep2 = true
    }
}
