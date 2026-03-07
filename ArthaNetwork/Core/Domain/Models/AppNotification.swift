import Foundation

struct AppNotification: Codable, Identifiable, Sendable {
    let id: String
    let userId: String?
    let title: String
    let body: String
    let type: String?
    let dealId: String?
    let isRead: Bool
    let createdAt: Date?
}

struct NotificationsPage: Codable, Sendable {
    let notifications: [AppNotification]
    let total: Int
    let unreadCount: Int
}
