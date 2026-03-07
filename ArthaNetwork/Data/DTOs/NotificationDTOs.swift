import Foundation

struct AnalyticsEvent: Encodable {
    let event: String
    let userId: String?
    let dealId: String?
    let caseId: String?
    let ts: String
    let extras: [String: String]?
}
