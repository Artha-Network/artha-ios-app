import Foundation

struct SignInRequest: Encodable {
    let pubkey: String
    /// The canonical auth message as a JSON **string** — the server does
    /// `JSON.parse(message)` and verifies the signature against `TextEncoder.encode(message)`.
    let message: String
    let signature: [UInt8]
}

struct SignInResponse: Decodable {
    let user: User
}

struct AuthMeResponse: Decodable {
    let user: User
    let profileComplete: Bool?
}
