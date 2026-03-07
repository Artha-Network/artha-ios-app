import SwiftUI

/// View modifier that redirects to the home/login screen when the user is not authenticated.
struct AuthGuard: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        if appState.isAuthenticated {
            content
        } else {
            HomeView()
        }
    }
}

extension View {
    /// Wraps a view so it only renders when authenticated.
    func requiresAuth() -> some View {
        modifier(AuthGuard())
    }
}
