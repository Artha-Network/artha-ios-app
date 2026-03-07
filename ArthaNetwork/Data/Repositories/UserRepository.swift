import Foundation

struct UserRepository {
    private let api = APIClient.shared

    func fetchMe() async throws -> User {
        try await api.get(APIEndpoints.usersMe)
    }

    func updateMe(displayName: String, emailAddress: String) async throws -> User {
        let body = UpdateProfileRequest(
            displayName: displayName,
            emailAddress: emailAddress
        )
        return try await api.patch(APIEndpoints.usersMe, body: body)
    }
}

private struct UpdateProfileRequest: Encodable {
    let displayName: String
    let emailAddress: String
}
