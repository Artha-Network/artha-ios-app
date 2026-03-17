import Foundation

struct AuthRepository {
    private let api = APIClient.shared

    func signIn(pubkey: String, message: String, signature: [UInt8]) async throws -> User {
        let body = SignInRequest(
            pubkey: pubkey,
            message: message,
            signature: signature
        )
        let response: SignInResponse = try await api.post(APIEndpoints.signIn, body: body)
        return response.user
    }

    func checkSession() async throws -> User {
        // GET /auth/me returns session info including user profile
        let response: AuthMeResponse = try await api.get(APIEndpoints.authMe)
        return response.user
    }

    func logout() async throws {
        let _: EmptyResponse = try await api.post(APIEndpoints.logout, body: EmptyBody())
    }

    func keepalive() async throws {
        let _: EmptyResponse = try await api.post(APIEndpoints.keepalive, body: EmptyBody())
    }
}

private struct EmptyResponse: Decodable {}
