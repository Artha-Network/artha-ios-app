import Foundation

struct CarEscrowPlanInput: Encodable {
    let priceUsd: Double
    let deliveryType: String
    let hasTitleInHand: Bool
    let odometerMiles: Int?
    let year: Int?
    let isSalvageTitle: Bool?
}
