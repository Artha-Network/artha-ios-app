import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
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
                NotificationRowView(notification: notification)
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

struct NotificationRowView: View {
    let notification: AppNotification

    var body: some View {
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
        .padding(.vertical, 4)
    }
}
