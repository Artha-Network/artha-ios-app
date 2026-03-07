import Foundation

struct NotificationRepository {
    private let api = APIClient.shared

    func fetchNotifications(wallet: String, limit: Int, unreadOnly: Bool) async throws -> NotificationsPage {
        try await api.get(APIEndpoints.notifications, queryItems: [
            .init(name: "wallet_address", value: wallet),
            .init(name: "limit", value: String(limit)),
            .init(name: "unread_only", value: String(unreadOnly))
        ])
    }

    func markAsRead(id: String) async throws {
        let _: EmptyResponse = try await api.patch(APIEndpoints.markRead(id), body: EmptyBody())
    }

    func markAllAsRead(wallet: String) async throws {
        let _: EmptyResponse = try await api.patch(
            APIEndpoints.markAllRead,
            body: MarkAllReadRequest(walletAddress: wallet)
        )
    }
}

private struct EmptyResponse: Decodable {}
private struct MarkAllReadRequest: Encodable {
    let walletAddress: String
}
