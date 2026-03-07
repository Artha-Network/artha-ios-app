import SwiftUI

@main
struct ArthaNetworkApp: App {
    @State private var appState = AppState()
    @State private var router = AppRouter()
    @State private var walletManager = WalletManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .environment(walletManager)
                .onOpenURL { url in
                    // Route artha:// deeplink callbacks (Phantom/Solflare responses) to WalletManager.
                    walletManager.handleCallback(url: url)
                }
        }
    }
}

// MARK: - Root View

/// Decides which top-level view to show based on authentication state.
/// Handles session restoration on first launch via a cookie check against the server.
struct RootView: View {
    @Environment(AppState.self) private var appState
    /// Guards against flashing HomeView for returning users with a valid session cookie.
    @State private var sessionRestored = false

    var body: some View {
        Group {
            if !sessionRestored {
                LaunchScreen()
            } else if appState.isAuthenticated {
                AuthenticatedTabView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessionRestored)
        .animation(.easeInOut(duration: 0.2), value: appState.isAuthenticated)
        .task {
            await restoreSession()
        }
    }

    /// Attempts to restore a prior session from the persisted httpOnly cookie.
    /// On 401 or network failure, silently stays on HomeView — no user action required.
    private func restoreSession() async {
        do {
            let user = try await AuthRepository().checkSession()
            appState.setAuthenticated(user: user)
            RequestInterceptor.startKeepalive()
            // Populate the unread badge immediately so it is correct before the
            // Notifications tab is opened. Errors are silently ignored — the badge
            // self-corrects when NotificationsView loads.
            if let page = try? await NotificationUseCase().fetchNotifications(
                wallet: user.walletAddress, limit: 1
            ) {
                appState.unreadNotificationCount = page.unreadCount
            }
        } catch {
            // Session absent or expired — unauthenticated state is correct.
        }
        sessionRestored = true
    }
}

private struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                ProgressView()
            }
        }
    }
}

// MARK: - Authenticated Shell

struct AuthenticatedTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.dealsPath) {
                DealListView()
                    .navigationDestination(for: AppRouter.Destination.self) { destination in
                        switch destination {
                        case .dealDetail(let id):
                            DealDetailView(dealId: id)
                        case .dealResolution(let id):
                            ResolutionView(dealId: id)
                        case .evidence(let id):
                            EvidenceListView(dealId: id)
                        case .dispute(let id):
                            DisputeView(dealId: id)
                        }
                    }
            }
            .tabItem { Label("Deals", systemImage: "list.bullet.rectangle") }
            .tag(AppTab.deals)

            EscrowTabView()
                .tabItem { Label("Create", systemImage: "plus.circle") }
                .tag(AppTab.create)

            NavigationStack {
                NotificationsView()
            }
            .badge(appState.unreadNotificationCount)
            .tabItem { Label("Notifications", systemImage: "bell") }
            .tag(AppTab.notifications)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.circle") }
            .tag(AppTab.profile)
        }
    }
}
