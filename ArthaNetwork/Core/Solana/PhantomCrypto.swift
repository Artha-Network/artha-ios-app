import Foundation
import CryptoKit
import Sodium

// MARK: - Errors

enum PhantomCryptoError: LocalizedError {
    case invalidPublicKey
    case invalidNonceLength(Int)
    case decryptionFailed
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            return "Phantom returned an invalid public key in the callback URL."
        case .invalidNonceLength(let len):
            return "NaCl box nonce must be 24 bytes; received \(len)."
        case .decryptionFailed:
            return "Failed to decrypt Phantom payload. The shared secret or ciphertext may be invalid."
        case .encryptionFailed:
            return "Failed to encrypt payload for Phantom."
        }
    }
}

// MARK: - PhantomCrypto

/// Cryptographic utilities for the Phantom wallet deeplink protocol.
///
/// ## Phantom Encryption Scheme
///
/// Phantom uses **NaCl box** for all encrypted channel payloads:
///
///   1. **X25519 DH** — derives a 32-byte shared secret from the two parties' keys.
///   2. **HSalsa20** — derives a symmetric key from the shared secret.
///   3. **XSalsa20-Poly1305** — authenticated encryption with the derived key and nonce.
///
/// `swift-sodium` handles all three steps in `sodium.box.open` / `sodium.box.seal`.
enum PhantomCrypto {

    // MARK: - X25519 DH (CryptoKit)

    /// Derives the raw 32-byte X25519 shared secret.
    ///
    /// This is the pre-HSalsa20 DH output. It is cached in `PhantomSession` for reference
    /// but cannot be used directly as the NaCl box key — libsodium handles HSalsa20 internally.
    static func x25519SharedSecret(
        appPrivateKeyBytes: Data,
        phantomPublicKeyBytes: Data
    ) throws -> Data {
        do {
            let privKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: appPrivateKeyBytes)
            let phantomPublicKey = try Curve25519.KeyAgreement.PublicKey(
                rawRepresentation: phantomPublicKeyBytes
            )
            let sharedSecret = try privKey.sharedSecretFromKeyAgreement(with: phantomPublicKey)
            return sharedSecret.withUnsafeBytes { Data($0) }
        } catch {
            throw PhantomCryptoError.invalidPublicKey
        }
    }

    // MARK: - NaCl Box Decrypt

    /// Decrypts a NaCl box ciphertext returned by Phantom in a deeplink callback.
    ///
    /// Used for both the `artha://connected` and `artha://signed` / `artha://signedTransaction` callbacks.
    ///
    /// - Parameters:
    ///   - ciphertext: Base58-decoded `data` field from the callback URL.
    ///   - nonce: 24-byte nonce — base58-decoded `nonce` field from the callback URL.
    ///   - appPrivateKeyBytes: Raw 32-byte X25519 session private key.
    ///   - phantomPublicKeyBytes: Raw 32-byte Phantom encryption public key from the callback URL.
    static func decryptBox(
        ciphertext: Data,
        nonce: Data,
        appPrivateKeyBytes: Data,
        phantomPublicKeyBytes: Data
    ) throws -> Data {
        guard nonce.count == 24 else {
            throw PhantomCryptoError.invalidNonceLength(nonce.count)
        }
        let sodium = Sodium()
        guard let plaintext = sodium.box.open(
            authenticatedCipherText: Bytes(ciphertext),
            senderPublicKey: Bytes(phantomPublicKeyBytes),
            recipientSecretKey: Bytes(appPrivateKeyBytes),
            nonce: Bytes(nonce)
        ) else {
            throw PhantomCryptoError.decryptionFailed
        }
        return Data(plaintext)
    }

    // MARK: - NaCl Box Encrypt

    /// Encrypts a payload for Phantom using NaCl box. Generates a random 24-byte nonce.
    ///
    /// Used for `signMessage` and `signTransaction` request payloads.
    ///
    /// - Parameters:
    ///   - message: The plaintext JSON payload to encrypt.
    ///   - appPrivateKeyBytes: Raw 32-byte X25519 session private key.
    ///   - phantomPublicKeyBytes: Phantom's encryption public key (from the connect callback).
    /// - Returns: `(ciphertext, nonce)` — both base58-encoded by the caller for the URL.
    static func encryptBox(
        message: Data,
        appPrivateKeyBytes: Data,
        phantomPublicKeyBytes: Data
    ) throws -> (ciphertext: Data, nonce: Data) {
        let sodium = Sodium()
        guard let sealed: (authenticatedCipherText: Bytes, nonce: Bytes) = sodium.box.seal(
            message: Bytes(message),
            recipientPublicKey: Bytes(phantomPublicKeyBytes),
            senderSecretKey: Bytes(appPrivateKeyBytes)
        ) else {
            throw PhantomCryptoError.encryptionFailed
        }
        return (Data(sealed.authenticatedCipherText), Data(sealed.nonce))
    }
}
