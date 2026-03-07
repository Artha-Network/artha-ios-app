import Foundation
import Observation

@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var error: AppError?
    /// Unread notification count — updated by NotificationsView and used to badge the tab.
    var unreadNotificationCount = 0

    // MARK: - Session Management

    func setAuthenticated(user: User) {
        self.currentUser = user
        self.isAuthenticated = true
    }

    func clearSession() {
        self.currentUser = nil
        self.isAuthenticated = false
        self.unreadNotificationCount = 0
    }

    var isProfileComplete: Bool {
        guard let user = currentUser else { return false }
        return user.displayName != nil && user.emailAddress != nil
    }
}

enum AppError: Error, Identifiable {
    case network(String)
    case auth(String)
    case wallet(String)
    case unknown(String)

    var id: String {
        switch self {
        case .network(let msg): return "network-\(msg)"
        case .auth(let msg): return "auth-\(msg)"
        case .wallet(let msg): return "wallet-\(msg)"
        case .unknown(let msg): return "unknown-\(msg)"
        }
    }

    var message: String {
        switch self {
        case .network(let msg), .auth(let msg),
             .wallet(let msg), .unknown(let msg):
            return msg
        }
    }
}
