import Foundation

/// Handles user profile fetching and updates.
struct ProfileUseCase {
    private let userRepo: UserRepository

    init(userRepo: UserRepository = .init()) {
        self.userRepo = userRepo
    }

    func fetchProfile() async throws -> User {
        try await userRepo.fetchMe()
    }

    func updateProfile(displayName: String, emailAddress: String) async throws -> User {
        try await userRepo.updateMe(displayName: displayName, emailAddress: emailAddress)
    }
}
