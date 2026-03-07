import Foundation

/// Base58 codec using the Bitcoin/Solana alphabet.
///
/// Solana and Phantom use Base58 (not Base58Check) for encoding public keys,
/// nonces, and encrypted payloads in deeplink URLs.
///
/// Alphabet: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
/// (digits 0, uppercase O, uppercase I, lowercase l omitted to avoid ambiguity)
enum Base58 {

    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    // Map from ASCII byte value to base58 digit index (0-57). Built once at first use.
    private static let decodeTable: [UInt8: Int] = {
        var table = [UInt8: Int]()
        for (index, char) in alphabet.enumerated() {
            if let ascii = char.asciiValue {
                table[ascii] = index
            }
        }
        return table
    }()

    // MARK: - Encode

    /// Encodes a byte array to a Base58 string.
    static func encode(_ bytes: [UInt8]) -> String {
        let leadingZeroCount = bytes.prefix(while: { $0 == 0 }).count

        // Convert base-256 → base-58 using a carry-based algorithm.
        var digits = [Int]()
        for byte in bytes {
            var carry = Int(byte)
            for i in 0..<digits.count {
                carry += digits[i] * 256
                digits[i] = carry % 58
                carry /= 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }

        // Leading zero bytes → leading '1' characters.
        let leadingOnes = String(repeating: "1", count: leadingZeroCount)
        let encoded = digits.reversed().map { String(alphabet[$0]) }.joined()
        return leadingOnes + encoded
    }

    // MARK: - Decode

    /// Decodes a Base58 string to bytes.
    /// Returns `nil` if the string contains a character not in the Base58 alphabet.
    static func decode(_ string: String) -> [UInt8]? {
        let leadingOneCount = string.prefix(while: { $0 == "1" }).count

        // Convert base-58 → base-256 using a carry-based algorithm.
        var bytes = [Int]()
        for char in string {
            guard let ascii = char.asciiValue,
                  let digitValue = decodeTable[ascii] else {
                return nil  // Character not in Base58 alphabet.
            }
            var carry = digitValue
            for i in 0..<bytes.count {
                carry += bytes[i] * 58
                bytes[i] = carry & 0xFF
                carry >>= 8
            }
            while carry > 0 {
                bytes.append(carry & 0xFF)
                carry >>= 8
            }
        }

        // Leading '1' characters → leading zero bytes.
        let leadingZeros = [UInt8](repeating: 0, count: leadingOneCount)
        let decoded = bytes.reversed().map { UInt8($0) }
        return leadingZeros + decoded
    }
}
