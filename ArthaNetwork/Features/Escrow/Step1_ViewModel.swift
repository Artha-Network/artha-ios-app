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

    /// The current user's wallet address — set by the View so we can reject self-as-counterparty.
    var myWalletAddress = ""

    private let dealRepo = DealRepository()

    /// Basic gate: disables the "Continue" button until minimum fields are populated.
    var isValid: Bool {
        !title.isEmpty
            && description.count >= 10
            && !counterpartyWallet.isEmpty
            && !counterpartyEmail.isEmpty
            && amount >= 10
            && amount <= 1_000_000
    }

    /// Detailed validation run on submit. Returns the first error message, or nil if all valid.
    private func validate() -> String? {
        if title.trimmingCharacters(in: .whitespaces).count < 3 {
            return "Title must be at least 3 characters."
        }
        if description.count < 10 || description.count > 1000 {
            return "Description must be 10–1,000 characters."
        }

        // Solana address: must be valid Base58 decoding to exactly 32 bytes.
        guard let decoded = Base58.decode(counterpartyWallet), decoded.count == 32 else {
            return "Counterparty wallet is not a valid Solana address."
        }
        if !myWalletAddress.isEmpty && counterpartyWallet == myWalletAddress {
            return "You cannot create a deal with yourself."
        }

        // Email: basic format check.
        let emailPattern = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#
        if counterpartyEmail.range(of: emailPattern, options: .regularExpression) == nil {
            return "Please enter a valid email address."
        }

        if amount < 10 || amount > 1_000_000 {
            return "Amount must be between $10 and $1,000,000."
        }

        // Deadline ordering (DatePickers enforce ranges, but guard explicitly).
        if fundingDeadline <= Date() {
            return "Funding deadline must be in the future."
        }
        if deliveryDeadline <= fundingDeadline {
            return "Delivery deadline must be after funding deadline."
        }
        if disputeDeadline <= deliveryDeadline {
            return "Dispute deadline must be after delivery deadline."
        }

        // VIN: exactly 17 alphanumeric characters if provided.
        if isCarSale && !vin.isEmpty {
            let alphanumeric = vin.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
            if vin.count != 17 || !alphanumeric {
                return "VIN must be exactly 17 alphanumeric characters."
            }
        }

        return nil
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
        error = nil

        // Run detailed validation before proceeding.
        if let validationError = validate() {
            error = validationError
            return
        }

        isLoading = true

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
