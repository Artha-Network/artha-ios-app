import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        List {
            if viewModel.notifications.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("You're all caught up.")
                )
            }

            ForEach(viewModel.notifications) { notification in
                Button {
                    if let dealId = notification.dealId {
                        router.navigateToDeal(dealId)
                    }
                } label: {
                    NotificationRowView(notification: notification)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    if !notification.isRead {
                        Button("Mark Read") {
                            Task { await viewModel.markAsRead(notification.id) }
                        }
                        .tint(.blue)
                    }
                }
                .listRowBackground(notification.isRead ? Color.clear : Color.blue.opacity(0.05))
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") {
                        Task { await viewModel.markAllAsRead() }
                    }
                    .font(.subheadline)
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .overlay {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                ProgressView()
            }
        }
        .alert("Failed to Load Notifications", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("Retry") { Task { await viewModel.refresh() } }
            Button("Cancel", role: .cancel) { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .onChange(of: viewModel.unreadCount) { _, count in
            appState.unreadNotificationCount = count
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .task {
            if let wallet = appState.currentUser?.walletAddress {
                viewModel.walletAddress = wallet
                await viewModel.load()
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRowView: View {
    let notification: AppNotification

    private var iconInfo: (name: String, color: Color) {
        guard let type = notification.type?.lowercased() else {
            return ("bell", .gray)
        }
        if type.contains("fund") && !type.contains("refund") {
            return ("dollarsign.circle.fill", .blue)
        }
        if type.contains("release") {
            return ("arrow.up.circle.fill", .green)
        }
        if type.contains("refund") {
            return ("arrow.down.circle.fill", .purple)
        }
        if type.contains("dispute") {
            return ("exclamationmark.triangle.fill", .orange)
        }
        if type.contains("resolv") || type.contains("arbitrat") {
            return ("scale.3d", .purple)
        }
        if type.contains("evidence") {
            return ("doc.text.fill", .indigo)
        }
        if type.contains("creat") || type.contains("initiat") {
            return ("plus.circle.fill", .gray)
        }
        return ("bell.fill", .gray)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            Image(systemName: iconInfo.name)
                .font(.title3)
                .foregroundStyle(iconInfo.color)
                .frame(width: 28, alignment: .center)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !notification.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                    Text(notification.title)
                        .font(.subheadline.bold())
                    Spacer()
                    if let date = notification.createdAt {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Chevron when navigable
            if notification.dealId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
