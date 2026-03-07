import Foundation

/// Handles notification fetching and read-status management.
struct NotificationUseCase {
    private let notifRepo: NotificationRepository

    init(notifRepo: NotificationRepository = .init()) {
        self.notifRepo = notifRepo
    }

    func fetchNotifications(wallet: String, limit: Int = 20, unreadOnly: Bool = false) async throws -> NotificationsPage {
        try await notifRepo.fetchNotifications(wallet: wallet, limit: limit, unreadOnly: unreadOnly)
    }

    func markAsRead(id: String) async throws {
        try await notifRepo.markAsRead(id: id)
    }

    func markAllAsRead(wallet: String) async throws {
        try await notifRepo.markAllAsRead(wallet: wallet)
    }
}
