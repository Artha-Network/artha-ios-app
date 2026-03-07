import SwiftUI
import Observation

enum AppTab: Hashable {
    case deals, create, notifications, profile
}

@Observable
final class AppRouter {
    var dealsPath = NavigationPath()
    var selectedTab: AppTab = .deals

    enum Destination: Hashable {
        case dealDetail(String)
        case dealResolution(String)
        case evidence(String)
        case dispute(String)
    }

    func navigateToDeal(_ dealId: String) {
        selectedTab = .deals
        dealsPath.append(Destination.dealDetail(dealId))
    }

    func navigateToResolution(_ dealId: String) {
        selectedTab = .deals
        dealsPath.append(Destination.dealResolution(dealId))
    }

    func navigateToEvidence(_ dealId: String) {
        dealsPath.append(Destination.evidence(dealId))
    }

    func resetDealsPath() {
        dealsPath = NavigationPath()
    }
}
