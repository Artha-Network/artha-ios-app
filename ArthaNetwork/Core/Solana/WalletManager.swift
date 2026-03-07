import Foundation
import Observation
import CryptoKit
import UIKit

// MARK: - Error

enum WalletError: LocalizedError {
    case notConnected
    case missingPublicKey
    case invalidCallback(String)
    case phantomNotInstalled
    case deeplinkNotImplemented
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No wallet connected. Please connect a wallet first."
        case .missingPublicKey:
            return "Could not retrieve the public key from the wallet."
        case .invalidCallback(let reason):
            return "Wallet callback error: \(reason)"
        case .phantomNotInstalled:
            return "Phantom is not installed. Download Phantom Wallet from the App Store and try again."
        case .deeplinkNotImplemented:
            return "This wallet is not yet supported. Phantom deeplinks are available; Solflare is coming soon."
        case .userCancelled:
            return "The action was cancelled."
        }
    }
}

// MARK: - Protocol

/// Abstracts wallet operations for testability and future wallet-type swapping.
protocol WalletProvider {
    var isConnected: Bool { get }
    var publicKey: String? { get }
    func connect() async throws
    func disconnect()
    func signMessage(_ message: Data) async throws -> Data
    func signTransaction(_ transaction: Data) async throws -> Data
}

// MARK: - Private Session Types

/// Phantom's connect callback decodes to this JSON shape.
private struct PhantomConnectPayload: Decodable {
    /// The user's Solana public key (base58).
    let publicKey: String
    /// Phantom session token — required in every subsequent sign request payload.
    let session: String
}

/// Phantom's sign-message callback decodes to this JSON shape.
private struct PhantomSignMessagePayload: Decodable {
    /// Base58-encoded Ed25519 signature.
    let signature: String
}

/// Phantom's sign-transaction callback decodes to this JSON shape.
private struct PhantomSignTransactionPayload: Decodable {
    /// Base58-encoded signed serialized transaction.
    let transaction: String
}

/// Stored after a successful connect. Used by sign-message and sign-transaction.
private struct PhantomSession {
    /// Raw 32-byte X25519 shared secret (pre-HSalsa20). Cached for reference.
    let sharedSecret: Data
    /// Phantom session token included in every sign request's encrypted payload.
    let sessionToken: String
    /// App's X25519 session public key — sent as `dapp_encryption_public_key` in sign URLs.
    let appPublicKeyBytes: Data
    /// App's X25519 session private key — used to encrypt outgoing sign payloads.
    let appPrivateKeyBytes: Data
    /// Phantom's X25519 encryption public key — the recipient key for outgoing sign payloads.
    let phantomPublicKeyBytes: Data
}

// MARK: - WalletManager

/// Manages wallet connection via Phantom (iOS deeplinks) or Solflare (future).
///
/// ## Architecture
///
/// Each async operation (connect, signMessage, signTransaction) suspends via
/// `withCheckedThrowingContinuation`. The continuation is stored as a class property
/// until the wallet app calls back through an `artha://` URL, which `ArthaNetworkApp`
/// routes here via `.onOpenURL { url in walletManager.handleCallback(url: url) }`.
///
/// ## Phantom Connect — Implementation Status
///
/// - Deeplink URL building:  ✅ real (X25519 keypair + Base58 + UIApplication.open)
/// - Phantom not-installed detection: ✅ real (canOpenURL, synchronous, MainActor)
/// - Callback URL parsing:   ✅ real (phantom_encryption_public_key, nonce, data)
/// - Base58 decoding:        ✅ real (Base58.decode)
/// - X25519 DH:              ✅ real (CryptoKit Curve25519)
/// - NaCl box decryption:    ✅ real (PhantomCrypto.decryptBox via swift-sodium)
///
/// ## Phantom Sign — Implementation Status
///
/// - signMessage:            ✅ real (NaCl box encrypt payload → phantom://v1/signMessage)
/// - signTransaction:        ✅ real (NaCl box encrypt payload → phantom://v1/signTransaction)
///
/// ## Solflare
///
/// - connect/sign:           🔶 not implemented (throws deeplinkNotImplemented)
@Observable
final class WalletManager: WalletProvider {
    var isConnected = false
    var publicKey: String?
    var walletType: WalletType?

    enum WalletType: String, CaseIterable {
        case phantom = "Phantom"
        case solflare = "Solflare"
    }

    // MARK: Continuations — at most one of each kind is live at any time.
    private var connectContinuation: CheckedContinuation<String, Error>?
    private var signMessageContinuation: CheckedContinuation<Data, Error>?
    private var signTransactionContinuation: CheckedContinuation<Data, Error>?

    // MARK: Phantom Session State

    /// Ephemeral X25519 keypair generated when connect() is initiated.
    /// Stored until the connect callback arrives, then migrated into PhantomSession.
    private var sessionPrivateKey: Curve25519.KeyAgreement.PrivateKey?

    /// Cached after a successful connect for use in subsequent sign requests.
    private var phantomSession: PhantomSession?

    // MARK: - Connection

    func connect() async throws {
        let pubkey: String = try await withCheckedThrowingContinuation { continuation in
            self.connectContinuation = continuation
            do {
                try self.openConnectDeeplink()
            } catch {
                self.connectContinuation = nil
                continuation.resume(throwing: error)
            }
        }
        self.publicKey = pubkey
        self.isConnected = true
    }

    func connect(type: WalletType) async throws {
        self.walletType = type
        try await connect()
    }

    func disconnect() {
        isConnected = false
        publicKey = nil
        walletType = nil
        sessionPrivateKey = nil
        phantomSession = nil
        cancelPendingCallbacks(reason: .userCancelled)
    }

    // MARK: - Signing

    func signMessage(_ message: Data) async throws -> Data {
        guard isConnected else { throw WalletError.notConnected }
        return try await withCheckedThrowingContinuation { continuation in
            self.signMessageContinuation = continuation
            do {
                try self.openSignMessageDeeplink(message: message)
            } catch {
                self.signMessageContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }

    func signTransaction(_ transaction: Data) async throws -> Data {
        guard isConnected else { throw WalletError.notConnected }
        return try await withCheckedThrowingContinuation { continuation in
            self.signTransactionContinuation = continuation
            do {
                try self.openSignTransactionDeeplink(transaction: transaction)
            } catch {
                self.signTransactionContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Deeplink Callback Router

    /// Entry point for all `artha://` deeplink responses from wallet apps.
    /// Wired from `ArthaNetworkApp` via `.onOpenURL { url in walletManager.handleCallback(url: url) }`.
    func handleCallback(url: URL) {
        guard url.scheme == AppConfiguration.appURLScheme else { return }
        switch url.host {
        case "connected":
            handleConnectCallback(url: url)
        case "signed":
            handleSignMessageCallback(url: url)
        case "signedTransaction":
            handleSignTransactionCallback(url: url)
        default:
            break
        }
    }

    // MARK: - Auth Helpers

    /// Builds the canonical sign-in message matching the actions-server contract.
    /// Keys are sorted for deterministic JSON serialization.
    func buildAuthMessage() -> (message: Data, messageDict: [String: String]) {
        let nonce = UUID().uuidString
        let ts = ISO8601DateFormatter().string(from: Date())
        let dict: [String: String] = [
            "app": "Artha Network",
            "action": "session_confirm",
            "nonce": nonce,
            "ts": ts
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return (data, dict)
    }

    // MARK: - Private: Phantom Connect Deeplink

    private func openConnectDeeplink() throws {
        switch walletType {
        case .phantom, .none:
            try openPhantomConnectDeeplink()
        case .solflare:
            throw WalletError.deeplinkNotImplemented
        }
    }

    private func openPhantomConnectDeeplink() throws {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        sessionPrivateKey = privateKey
        let sessionPubKeyBase58 = Base58.encode(Array(privateKey.publicKey.rawRepresentation))

        var components = URLComponents()
        components.scheme = "phantom"
        components.host = "v1"
        components.path = "/connect"
        components.queryItems = [
            URLQueryItem(name: "app_url",                    value: "https://arthanetwork.com"),
            URLQueryItem(name: "redirect_link",              value: "artha://connected"),
            URLQueryItem(name: "cluster",                    value: AppConfiguration.solanaCluster),
            URLQueryItem(name: "dapp_encryption_public_key", value: sessionPubKeyBase58)
        ]

        guard let url = components.url else {
            sessionPrivateKey = nil
            throw WalletError.invalidCallback("Failed to build Phantom connect URL")
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard UIApplication.shared.canOpenURL(URL(string: "phantom://")!) else {
                self.connectContinuation?.resume(throwing: WalletError.phantomNotInstalled)
                self.connectContinuation = nil
                self.sessionPrivateKey = nil
                return
            }
            await UIApplication.shared.open(url, options: [:])
        }
    }

    // MARK: - Private: Phantom Connect Callback

    private func handleConnectCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            failConnect(with: .invalidCallback("Malformed callback URL"))
            return
        }

        let params = queryParams(from: components)

        if let errorCode = params["errorCode"] {
            let message = params["errorMessage"] ?? "Phantom rejected the connection (code: \(errorCode))"
            failConnect(with: .invalidCallback(message))
            sessionPrivateKey = nil
            return
        }

        guard let phantomPubKeyBase58 = params["phantom_encryption_public_key"],
              let nonceBase58 = params["nonce"],
              let dataBase58 = params["data"] else {
            failConnect(with: .invalidCallback(
                "Missing required fields: phantom_encryption_public_key, nonce, data"
            ))
            sessionPrivateKey = nil
            return
        }

        guard let phantomPubKeyRaw = Base58.decode(phantomPubKeyBase58),
              let nonceRaw = Base58.decode(nonceBase58),
              let ciphertextRaw = Base58.decode(dataBase58) else {
            failConnect(with: .invalidCallback("Failed to base58-decode callback fields"))
            sessionPrivateKey = nil
            return
        }

        let phantomPubKeyBytes = Data(phantomPubKeyRaw)
        let nonce = Data(nonceRaw)
        let ciphertext = Data(ciphertextRaw)

        // Consume the session private key — it is migrated into PhantomSession.
        guard let privKey = sessionPrivateKey else {
            failConnect(with: .invalidCallback("No session key — possible duplicate or stale callback"))
            return
        }
        sessionPrivateKey = nil

        let appPrivateKeyBytes = Data(privKey.rawRepresentation)
        let appPublicKeyBytes = Data(privKey.publicKey.rawRepresentation)

        do {
            // X25519 DH — cached for reference in PhantomSession.
            let sharedSecretData = try PhantomCrypto.x25519SharedSecret(
                appPrivateKeyBytes: appPrivateKeyBytes,
                phantomPublicKeyBytes: phantomPubKeyBytes
            )

            // NaCl box decrypt — HSalsa20 + XSalsa20-Poly1305 via swift-sodium.
            let plaintext = try PhantomCrypto.decryptBox(
                ciphertext: ciphertext,
                nonce: nonce,
                appPrivateKeyBytes: appPrivateKeyBytes,
                phantomPublicKeyBytes: phantomPubKeyBytes
            )

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let payload = try decoder.decode(PhantomConnectPayload.self, from: plaintext)

            // Store session — private key and phantom public key are kept for sign requests.
            phantomSession = PhantomSession(
                sharedSecret: sharedSecretData,
                sessionToken: payload.session,
                appPublicKeyBytes: appPublicKeyBytes,
                appPrivateKeyBytes: appPrivateKeyBytes,
                phantomPublicKeyBytes: phantomPubKeyBytes
            )

            connectContinuation?.resume(returning: payload.publicKey)
            connectContinuation = nil

        } catch {
            connectContinuation?.resume(throwing: error)
            connectContinuation = nil
        }
    }

    // MARK: - Private: Sign Message Deeplink

    private func openSignMessageDeeplink(message: Data) throws {
        guard let session = phantomSession else {
            throw WalletError.notConnected
        }

        // Payload: { "message": base58(messageBytes), "session": sessionToken }
        let payloadDict: [String: String] = [
            "message": Base58.encode(Array(message)),
            "session": session.sessionToken
        ]
        let payloadData = try JSONSerialization.data(
            withJSONObject: payloadDict, options: [.sortedKeys]
        )

        let (ciphertext, nonce) = try PhantomCrypto.encryptBox(
            message: payloadData,
            appPrivateKeyBytes: session.appPrivateKeyBytes,
            phantomPublicKeyBytes: session.phantomPublicKeyBytes
        )

        var components = URLComponents()
        components.scheme = "phantom"
        components.host = "v1"
        components.path = "/signMessage"
        components.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: Base58.encode(Array(session.appPublicKeyBytes))),
            URLQueryItem(name: "nonce",                      value: Base58.encode(Array(nonce))),
            URLQueryItem(name: "redirect_link",              value: "artha://signed"),
            URLQueryItem(name: "payload",                    value: Base58.encode(Array(ciphertext)))
        ]

        guard let url = components.url else {
            throw WalletError.invalidCallback("Failed to build Phantom signMessage URL")
        }

        Task { @MainActor in
            await UIApplication.shared.open(url, options: [:])
        }
    }

    // MARK: - Private: Sign Transaction Deeplink

    private func openSignTransactionDeeplink(transaction: Data) throws {
        guard let session = phantomSession else {
            throw WalletError.notConnected
        }

        // Payload: { "transaction": base58(serializedTx), "session": sessionToken }
        let payloadDict: [String: String] = [
            "transaction": Base58.encode(Array(transaction)),
            "session": session.sessionToken
        ]
        let payloadData = try JSONSerialization.data(
            withJSONObject: payloadDict, options: [.sortedKeys]
        )

        let (ciphertext, nonce) = try PhantomCrypto.encryptBox(
            message: payloadData,
            appPrivateKeyBytes: session.appPrivateKeyBytes,
            phantomPublicKeyBytes: session.phantomPublicKeyBytes
        )

        var components = URLComponents()
        components.scheme = "phantom"
        components.host = "v1"
        components.path = "/signTransaction"
        components.queryItems = [
            URLQueryItem(name: "dapp_encryption_public_key", value: Base58.encode(Array(session.appPublicKeyBytes))),
            URLQueryItem(name: "nonce",                      value: Base58.encode(Array(nonce))),
            URLQueryItem(name: "redirect_link",              value: "artha://signedTransaction"),
            URLQueryItem(name: "payload",                    value: Base58.encode(Array(ciphertext)))
        ]

        guard let url = components.url else {
            throw WalletError.invalidCallback("Failed to build Phantom signTransaction URL")
        }

        Task { @MainActor in
            await UIApplication.shared.open(url, options: [:])
        }
    }

    // MARK: - Private: Sign Message Callback

    private func handleSignMessageCallback(url: URL) {
        guard let session = phantomSession else {
            signMessageContinuation?.resume(throwing: WalletError.notConnected)
            signMessageContinuation = nil
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            signMessageContinuation?.resume(throwing: WalletError.invalidCallback("Malformed signed callback URL"))
            signMessageContinuation = nil
            return
        }

        let params = queryParams(from: components)

        if let errorCode = params["errorCode"] {
            let message = params["errorMessage"] ?? "Phantom rejected sign-message (code: \(errorCode))"
            signMessageContinuation?.resume(throwing: WalletError.invalidCallback(message))
            signMessageContinuation = nil
            return
        }

        guard let nonceBase58 = params["nonce"],
              let dataBase58 = params["data"],
              let nonceRaw = Base58.decode(nonceBase58),
              let ciphertextRaw = Base58.decode(dataBase58) else {
            signMessageContinuation?.resume(throwing: WalletError.invalidCallback(
                "Missing or undecodable nonce/data in signed callback"
            ))
            signMessageContinuation = nil
            return
        }

        do {
            let plaintext = try PhantomCrypto.decryptBox(
                ciphertext: Data(ciphertextRaw),
                nonce: Data(nonceRaw),
                appPrivateKeyBytes: session.appPrivateKeyBytes,
                phantomPublicKeyBytes: session.phantomPublicKeyBytes
            )
            // Response: { "signature": "<base58 Ed25519 signature>" }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let payload = try decoder.decode(PhantomSignMessagePayload.self, from: plaintext)
            guard let signatureBytes = Base58.decode(payload.signature) else {
                throw WalletError.invalidCallback("Invalid base58 signature in Phantom response")
            }
            signMessageContinuation?.resume(returning: Data(signatureBytes))
            signMessageContinuation = nil
        } catch {
            signMessageContinuation?.resume(throwing: error)
            signMessageContinuation = nil
        }
    }

    // MARK: - Private: Sign Transaction Callback

    private func handleSignTransactionCallback(url: URL) {
        guard let session = phantomSession else {
            signTransactionContinuation?.resume(throwing: WalletError.notConnected)
            signTransactionContinuation = nil
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            signTransactionContinuation?.resume(throwing: WalletError.invalidCallback("Malformed signedTransaction callback URL"))
            signTransactionContinuation = nil
            return
        }

        let params = queryParams(from: components)

        if let errorCode = params["errorCode"] {
            let message = params["errorMessage"] ?? "Phantom rejected sign-transaction (code: \(errorCode))"
            signTransactionContinuation?.resume(throwing: WalletError.invalidCallback(message))
            signTransactionContinuation = nil
            return
        }

        guard let nonceBase58 = params["nonce"],
              let dataBase58 = params["data"],
              let nonceRaw = Base58.decode(nonceBase58),
              let ciphertextRaw = Base58.decode(dataBase58) else {
            signTransactionContinuation?.resume(throwing: WalletError.invalidCallback(
                "Missing or undecodable nonce/data in signedTransaction callback"
            ))
            signTransactionContinuation = nil
            return
        }

        do {
            let plaintext = try PhantomCrypto.decryptBox(
                ciphertext: Data(ciphertextRaw),
                nonce: Data(nonceRaw),
                appPrivateKeyBytes: session.appPrivateKeyBytes,
                phantomPublicKeyBytes: session.phantomPublicKeyBytes
            )
            // Response: { "transaction": "<base58 signed serialized tx>" }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let payload = try decoder.decode(PhantomSignTransactionPayload.self, from: plaintext)
            guard let txBytes = Base58.decode(payload.transaction) else {
                throw WalletError.invalidCallback("Invalid base58 transaction in Phantom response")
            }
            signTransactionContinuation?.resume(returning: Data(txBytes))
            signTransactionContinuation = nil
        } catch {
            signTransactionContinuation?.resume(throwing: error)
            signTransactionContinuation = nil
        }
    }

    // MARK: - Private: Helpers

    private func failConnect(with error: WalletError) {
        connectContinuation?.resume(throwing: error)
        connectContinuation = nil
    }

    private func cancelPendingCallbacks(reason: WalletError) {
        connectContinuation?.resume(throwing: reason)
        connectContinuation = nil
        signMessageContinuation?.resume(throwing: reason)
        signMessageContinuation = nil
        signTransactionContinuation?.resume(throwing: reason)
        signTransactionContinuation = nil
    }

    /// Converts URLComponents query items to a [String: String] dictionary.
    private func queryParams(from components: URLComponents) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
    }
}
