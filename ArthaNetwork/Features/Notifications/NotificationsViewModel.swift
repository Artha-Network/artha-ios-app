import Foundation
import Observation

@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var unreadCount = 0
    var isLoading = false
    var error: String?
    var walletAddress = ""

    private let notifUseCase = NotificationUseCase()
    private var pollingTask: Task<Void, Never>?

    func load() async {
        isLoading = true
        await fetch()
        startPolling()
        isLoading = false
    }

    private func fetch() async {
        guard !walletAddress.isEmpty else { return }
        do {
            let page = try await notifUseCase.fetchNotifications(wallet: walletAddress, limit: 30)
            notifications = page.notifications
            unreadCount = page.unreadCount
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await fetch()
    }

    func markAsRead(_ id: String) async {
        do {
            try await notifUseCase.markAsRead(id: id)
            // AppNotification is an immutable struct, so we reload rather than mutate in place.
            await fetch()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        guard !walletAddress.isEmpty else { return }
        do {
            try await notifUseCase.markAllAsRead(wallet: walletAddress)
            await fetch()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Poll every 60 seconds for new notifications (mirrors web-app polling interval).
    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await fetch()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
    }
}
