import Foundation

/// Handles wallet-based authentication flow.
struct AuthUseCase {
    private let authRepo: AuthRepository
    private let wallet: WalletManager

    init(authRepo: AuthRepository = .init(), wallet: WalletManager) {
        self.authRepo = authRepo
        self.wallet = wallet
    }

    /// Full sign-in flow: build message, sign with wallet, send to server.
    func signIn() async throws -> User {
        // 1. Build canonical auth message
        let (messageData, messageDict) = wallet.buildAuthMessage()

        // 2. Sign with wallet
        let signature = try await wallet.signMessage(messageData)

        // 3. Send to server
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }
        let user = try await authRepo.signIn(
            pubkey: pubkey,
            message: messageDict,
            signature: Array(signature)
        )

        // 4. Start keepalive
        RequestInterceptor.startKeepalive()

        return user
    }

    /// Check if the current session is still valid.
    func checkSession() async throws -> User {
        try await authRepo.checkSession()
    }

    /// Log out: clear session on server and locally.
    func logout() async throws {
        try await authRepo.logout()
        RequestInterceptor.stopKeepalive()
        RequestInterceptor.clearCookies()
        wallet.disconnect()
    }
}
