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
        // 1. Build canonical auth message (JSON bytes with sorted keys)
        let (messageData, _) = wallet.buildAuthMessage()

        // 2. Sign with wallet — Phantom signs these exact bytes
        let signature = try await wallet.signMessage(messageData)

        // 3. Send to server — message must be the JSON *string* (not a dictionary)
        //    because the server does JSON.parse(message) and verifies the signature
        //    against TextEncoder.encode(message).
        guard let pubkey = wallet.publicKey else {
            throw AppError.wallet("No wallet connected")
        }
        guard let messageString = String(data: messageData, encoding: .utf8) else {
            throw AppError.wallet("Failed to encode auth message")
        }
        let user = try await authRepo.signIn(
            pubkey: pubkey,
            message: messageString,
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
