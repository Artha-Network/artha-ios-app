import Foundation

struct SignInRequest: Encodable {
    let pubkey: String
    let message: [String: String]
    let signature: [UInt8]
}

struct AuthMeResponse: Decodable {
    let user: User
    let profileComplete: Bool?
}
