//
// RoomAuthenticationService.swift
// bitchat
//
// HMAC-based message authentication for tournament rooms.
// Part of BeyScore Tournament System.
//

import Foundation
import CryptoKit

/// Service for signing and validating tournament room messages using HMAC-SHA256.
/// All tournament messages are signed with the room code to ensure only
/// devices with the correct code can participate.
final class RoomAuthenticationService {

    // MARK: - Singleton

    static let shared = RoomAuthenticationService()

    private init() {}

    // MARK: - Signature Length

    /// The length of HMAC-SHA256 signatures in bytes
    static let signatureLength = 32

    // MARK: - Signing

    /// Signs data using HMAC-SHA256 with the room code's derived key.
    /// - Parameters:
    ///   - data: The data to sign
    ///   - roomCode: The room code to use for signing
    /// - Returns: A 32-byte HMAC signature
    func sign(data: Data, roomCode: RoomCode) -> Data {
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: roomCode.hmacKey)
        return Data(signature)
    }

    /// Signs data using HMAC-SHA256 with a raw code string.
    /// Convenience method for when you have the code string directly.
    /// - Parameters:
    ///   - data: The data to sign
    ///   - codeString: The 6-digit room code string
    /// - Returns: A 32-byte HMAC signature, or nil if the code is invalid
    func sign(data: Data, codeString: String) -> Data? {
        guard let roomCode = RoomCode(code: codeString) else {
            return nil
        }
        return sign(data: data, roomCode: roomCode)
    }

    // MARK: - Validation

    /// Validates an HMAC signature against data using the room code.
    /// - Parameters:
    ///   - data: The data that was signed
    ///   - signature: The HMAC signature to validate
    ///   - roomCode: The room code to use for validation
    /// - Returns: true if the signature is valid
    func validate(data: Data, signature: Data, roomCode: RoomCode) -> Bool {
        guard signature.count == Self.signatureLength else {
            return false
        }

        let expectedSignature = sign(data: data, roomCode: roomCode)
        return constantTimeCompare(signature, expectedSignature)
    }

    /// Validates an HMAC signature against data using a raw code string.
    /// - Parameters:
    ///   - data: The data that was signed
    ///   - signature: The HMAC signature to validate
    ///   - codeString: The 6-digit room code string
    /// - Returns: true if the signature is valid and code is valid
    func validate(data: Data, signature: Data, codeString: String) -> Bool {
        guard let roomCode = RoomCode(code: codeString) else {
            return false
        }
        return validate(data: data, signature: signature, roomCode: roomCode)
    }

    // MARK: - Packet Helpers

    /// Creates a signed packet by appending the HMAC signature to the payload.
    /// Format: [payload][32-byte HMAC]
    /// - Parameters:
    ///   - payload: The packet payload to sign
    ///   - roomCode: The room code to use for signing
    /// - Returns: The payload with signature appended
    func createSignedPacket(payload: Data, roomCode: RoomCode) -> Data {
        let signature = sign(data: payload, roomCode: roomCode)
        var signedPacket = payload
        signedPacket.append(signature)
        return signedPacket
    }

    /// Extracts and validates the payload from a signed packet.
    /// Format expected: [payload][32-byte HMAC]
    /// - Parameters:
    ///   - packet: The signed packet
    ///   - roomCode: The room code to use for validation
    /// - Returns: The payload if signature is valid, nil otherwise
    func extractPayload(from packet: Data, roomCode: RoomCode) -> Data? {
        guard packet.count > Self.signatureLength else {
            return nil
        }

        let payloadEndIndex = packet.count - Self.signatureLength
        let payload = packet.prefix(payloadEndIndex)
        let signature = packet.suffix(Self.signatureLength)

        if validate(data: payload, signature: signature, roomCode: roomCode) {
            return Data(payload)
        }
        return nil
    }

    // MARK: - Security

    /// Performs constant-time comparison to prevent timing attacks.
    /// - Parameters:
    ///   - a: First data to compare
    ///   - b: Second data to compare
    /// - Returns: true if both data are equal
    private func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else {
            return false
        }

        var result: UInt8 = 0
        for (x, y) in zip(a, b) {
            result |= x ^ y
        }
        return result == 0
    }
}

// MARK: - Error Types

enum RoomAuthenticationError: Error, LocalizedError {
    case invalidRoomCode
    case invalidSignature
    case packetTooShort
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidRoomCode:
            return "Invalid room code format"
        case .invalidSignature:
            return "Message signature validation failed"
        case .packetTooShort:
            return "Packet too short to contain signature"
        case .signingFailed:
            return "Failed to sign message"
        }
    }
}
