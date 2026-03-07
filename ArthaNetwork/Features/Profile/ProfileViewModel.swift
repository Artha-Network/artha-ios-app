import Foundation
import Observation

@Observable
final class ProfileViewModel {
    var displayName = ""
    var emailAddress = ""
    var isLoading = false
    var isSaved = false
    var error: String?

    private let profileUseCase = ProfileUseCase()

    func loadProfile() async {
        isSaved = false
        isLoading = true
        do {
            let user = try await profileUseCase.fetchProfile()
            displayName = user.displayName ?? ""
            emailAddress = user.emailAddress ?? ""
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Saves the profile and returns the updated User so the caller can sync AppState.
    /// Returns nil if validation fails or the request errors.
    func saveProfile() async -> User? {
        guard !displayName.isEmpty, !emailAddress.isEmpty else {
            error = "Please fill in all fields"
            return nil
        }
        isSaved = false
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let updatedUser = try await profileUseCase.updateProfile(
                displayName: displayName,
                emailAddress: emailAddress
            )
            isSaved = true
            return updatedUser
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Logs out the user:
    ///   1. Calls POST /auth/logout on the server (clears the httpOnly session cookie)
    ///   2. Cancels the keepalive timer and clears local cookies
    ///   3. Disconnects the wallet
    ///   4. Clears AppState — triggers navigation back to HomeView
    ///
    /// Server errors are intentionally swallowed so local state is always cleared even
    /// if the network is unreachable. The user must always be able to log out.
    func logout(wallet: WalletManager, appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthUseCase(authRepo: AuthRepository(), wallet: wallet).logout()
        } catch {
            // Network or server error — proceed with local logout regardless
        }
        appState.clearSession()
    }
}
