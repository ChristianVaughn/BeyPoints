//
// RoomCode.swift
// bitchat
//
// Tournament room authentication using 6-digit codes.
// Part of BeyScore Tournament System.
//

import Foundation
import CryptoKit

/// A 6-digit room code used for tournament authentication.
/// The code is used to derive an HMAC key for message signing/validation.
struct RoomCode: Equatable, Hashable, Codable {

    /// The 6-digit code string (e.g., "847291")
    let code: String

    /// The HMAC key derived from the room code
    let hmacKey: SymmetricKey

    // MARK: - Initialization

    /// Creates a RoomCode from a 6-digit string.
    /// - Parameter code: A string containing exactly 6 numeric digits
    /// - Returns: A RoomCode if valid, nil otherwise
    init?(code: String) {
        // Validate: exactly 6 numeric digits
        guard code.count == 6,
              code.allSatisfy({ $0.isNumber }) else {
            return nil
        }

        self.code = code
        self.hmacKey = RoomCode.deriveKey(from: code)
    }

    /// Generates a random 6-digit room code.
    /// - Returns: A new RoomCode with a randomly generated code
    static func generate() -> RoomCode {
        let randomCode = String(format: "%06d", Int.random(in: 0...999999))
        return RoomCode(code: randomCode)!
    }

    // MARK: - Key Derivation

    /// Derives an HMAC key from the room code using SHA256.
    /// Uses a fixed salt to ensure consistent key derivation across devices.
    private static func deriveKey(from code: String) -> SymmetricKey {
        // Salt for key derivation - fixed for cross-device compatibility
        let salt = "beyscore-tournament-room-v1"
        let keyMaterial = "\(salt):\(code)"

        // Hash the key material to get a 256-bit key
        let hash = SHA256.hash(data: Data(keyMaterial.utf8))
        return SymmetricKey(data: hash)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let codeString = try container.decode(String.self, forKey: .code)

        guard let roomCode = RoomCode(code: codeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .code,
                in: container,
                debugDescription: "Invalid room code format"
            )
        }

        self.code = roomCode.code
        self.hmacKey = roomCode.hmacKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
    }

    // MARK: - Equatable/Hashable

    static func == (lhs: RoomCode, rhs: RoomCode) -> Bool {
        return lhs.code == rhs.code
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

// MARK: - Room Code Validation

extension RoomCode {

    /// Validates a string as a potential room code without creating the full object.
    /// - Parameter string: The string to validate
    /// - Returns: true if the string is a valid 6-digit code
    static func isValid(_ string: String) -> Bool {
        return string.count == 6 && string.allSatisfy({ $0.isNumber })
    }

    /// Formats a partial code input for display (adds dashes for readability).
    /// - Parameter partial: The partial code being entered
    /// - Returns: Formatted string like "847-291"
    static func formatForDisplay(_ partial: String) -> String {
        let digits = partial.filter { $0.isNumber }
        if digits.count <= 3 {
            return digits
        } else {
            let firstHalf = digits.prefix(3)
            let secondHalf = digits.dropFirst(3).prefix(3)
            return "\(firstHalf)-\(secondHalf)"
        }
    }
}
