import Foundation
import Observation

@Observable
final class AuthViewModel {
    var isLoading = false
    var error: String?
    var currentStep: AuthStep?

    enum AuthStep {
        case connectingWallet
        case signingMessage
        case authenticating

        var statusText: String {
            switch self {
            case .connectingWallet:
                return "Waiting for Phantom to connect\u{2026}"
            case .signingMessage:
                return "Waiting for Phantom to sign\u{2026}"
            case .authenticating:
                return "Authenticating with server\u{2026}"
            }
        }

        /// Secondary hint shown below the status text, or nil when no hint is needed.
        var hintText: String? {
            switch self {
            case .connectingWallet, .signingMessage:
                return "Return to this app after approving in Phantom."
            case .authenticating:
                return nil
            }
        }
    }

    private let wallet: WalletManager
    private let authUseCase: AuthUseCase

    init(wallet: WalletManager) {
        self.wallet = wallet
        self.authUseCase = AuthUseCase(authRepo: AuthRepository(), wallet: wallet)
    }

    /// Full sign-in flow:
    ///   1. Connect wallet via deeplink (suspends until artha://connected callback)
    ///   2. Build canonical auth message and sign it (suspends until artha://signed callback)
    ///   3. POST pubkey + message + signature to /auth/sign-in
    ///
    /// Returns the authenticated User. The caller is responsible for calling
    /// `appState.setAuthenticated(user:)` — the ViewModel intentionally does not hold AppState.
    func signIn(type: WalletManager.WalletType) async throws -> User {
        isLoading = true
        error = nil
        defer {
            isLoading = false
            currentStep = nil
        }

        currentStep = .connectingWallet
        do {
            try await wallet.connect(type: type)
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        // authUseCase.signIn() calls wallet.signMessage() (deeplink #2) then POST /auth/sign-in.
        currentStep = .signingMessage
        let user: User
        do {
            user = try await authUseCase.signIn()
        } catch {
            self.error = error.localizedDescription
            throw error
        }

        return user
    }

    /// Cancels any in-flight wallet operation.
    /// `wallet.disconnect()` resumes all pending continuations with `.userCancelled`,
    /// which unblocks the suspended `signIn` Task and surfaces the error in `viewModel.error`.
    func cancel() {
        wallet.disconnect()
    }
}
