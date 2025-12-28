//
// TournamentMessages.swift
// bitchat
//
// Tournament-specific message types for the BeyScore Tournament System.
// These messages are wrapped in ROOM_MESSAGE packets and HMAC-signed.
//

import Foundation

// MARK: - Tournament Message Types

/// Types of tournament messages that can be sent within a room.
/// These are the inner message types within a roomMessage packet.
enum TournamentMessageType: UInt8 {
    // Room management
    case joinRoom = 0x40        // Scoreboard requests to join tournament room
    case roomJoined = 0x41      // Master confirms join
    case leaveRoom = 0x42       // Device leaves room

    // Match management
    case assignMatch = 0x43     // Master assigns match to scoreboard
    case matchAccepted = 0x44   // Scoreboard confirms match receipt
    case matchUnassigned = 0x4A // Master unassigns match from scoreboard

    // Score submission
    case submitScore = 0x45     // Scoreboard sends final result
    case approveScore = 0x46    // Master approves submission
    case rejectScore = 0x47     // Master rejects submission

    // State sync
    case tournamentUpdate = 0x48 // Master broadcasts full tournament state
    case requestState = 0x49     // Device requests current tournament state

    var description: String {
        switch self {
        case .joinRoom: return "joinRoom"
        case .roomJoined: return "roomJoined"
        case .leaveRoom: return "leaveRoom"
        case .assignMatch: return "assignMatch"
        case .matchAccepted: return "matchAccepted"
        case .matchUnassigned: return "matchUnassigned"
        case .submitScore: return "submitScore"
        case .approveScore: return "approveScore"
        case .rejectScore: return "rejectScore"
        case .tournamentUpdate: return "tournamentUpdate"
        case .requestState: return "requestState"
        }
    }
}

// MARK: - Device Mode

/// The mode a device is operating in within the tournament system.
enum DeviceMode: UInt8, Codable {
    case master = 0x01      // Tournament organizer device
    case scoreboard = 0x02  // Scoring station device
}

// MARK: - Base Tournament Message

/// Base protocol for all tournament messages.
protocol TournamentMessage {
    var messageType: TournamentMessageType { get }
    func encode() -> Data
    static func decode(from data: Data) -> Self?
}

// MARK: - Join Room Message

/// Sent by a scoreboard device to request joining a tournament room.
struct JoinRoomMessage: TournamentMessage {
    let messageType = TournamentMessageType.joinRoom
    let deviceId: String
    let deviceName: String
    let mode: DeviceMode

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)
        data.append(mode.rawValue)

        // Device ID (length-prefixed string)
        let deviceIdData = Data(deviceId.utf8)
        data.append(UInt8(deviceIdData.count))
        data.append(deviceIdData)

        // Device name (length-prefixed string)
        let deviceNameData = Data(deviceName.utf8)
        data.append(UInt8(deviceNameData.count))
        data.append(deviceNameData)

        return data
    }

    static func decode(from data: Data) -> JoinRoomMessage? {
        guard data.count >= 3,
              data[0] == TournamentMessageType.joinRoom.rawValue,
              let mode = DeviceMode(rawValue: data[1]) else {
            return nil
        }

        var offset = 2

        // Device ID
        guard offset < data.count else { return nil }
        let deviceIdLength = Int(data[offset])
        offset += 1
        guard offset + deviceIdLength <= data.count else { return nil }
        let deviceId = String(data: data[offset..<offset+deviceIdLength], encoding: .utf8) ?? ""
        offset += deviceIdLength

        // Device name
        guard offset < data.count else { return nil }
        let deviceNameLength = Int(data[offset])
        offset += 1
        guard offset + deviceNameLength <= data.count else { return nil }
        let deviceName = String(data: data[offset..<offset+deviceNameLength], encoding: .utf8) ?? ""

        return JoinRoomMessage(deviceId: deviceId, deviceName: deviceName, mode: mode)
    }
}

// MARK: - Room Joined Message

/// Sent by master to confirm a device has joined the room.
struct RoomJoinedMessage: TournamentMessage {
    let messageType = TournamentMessageType.roomJoined
    let success: Bool
    let tournamentName: String?
    let errorMessage: String?

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)
        data.append(success ? 0x01 : 0x00)

        if success, let name = tournamentName {
            let nameData = Data(name.utf8)
            data.append(UInt8(nameData.count))
            data.append(nameData)
        } else if let error = errorMessage {
            let errorData = Data(error.utf8)
            data.append(UInt8(errorData.count))
            data.append(errorData)
        } else {
            data.append(0x00) // No additional data
        }

        return data
    }

    static func decode(from data: Data) -> RoomJoinedMessage? {
        guard data.count >= 2,
              data[0] == TournamentMessageType.roomJoined.rawValue else {
            return nil
        }

        let success = data[1] == 0x01
        var additionalString: String? = nil

        if data.count > 2 {
            let strLength = Int(data[2])
            if data.count >= 3 + strLength {
                additionalString = String(data: data[3..<3+strLength], encoding: .utf8)
            }
        }

        if success {
            return RoomJoinedMessage(success: true, tournamentName: additionalString, errorMessage: nil)
        } else {
            return RoomJoinedMessage(success: false, tournamentName: nil, errorMessage: additionalString)
        }
    }
}

// MARK: - Assign Match Message

/// Sent by master to assign a match to a scoreboard device.
struct AssignMatchMessage: TournamentMessage, Codable {
    let messageType = TournamentMessageType.assignMatch
    let matchId: String
    let player1Name: String
    let player2Name: String
    let generation: UInt8       // Beyblade generation
    let matchType: UInt8        // Points to win
    let bestOf: UInt8           // Best-of setting (0 = none)
    let ownFinishEnabled: Bool

    // Codable support - exclude computed messageType property
    private enum CodingKeys: String, CodingKey {
        case matchId, player1Name, player2Name, generation, matchType, bestOf, ownFinishEnabled
    }

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        // Match ID
        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        // Player 1 name
        let p1Data = Data(player1Name.utf8)
        data.append(UInt8(p1Data.count))
        data.append(p1Data)

        // Player 2 name
        let p2Data = Data(player2Name.utf8)
        data.append(UInt8(p2Data.count))
        data.append(p2Data)

        // Config bytes
        data.append(generation)
        data.append(matchType)
        data.append(bestOf)
        data.append(ownFinishEnabled ? 0x01 : 0x00)

        return data
    }

    static func decode(from data: Data) -> AssignMatchMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.assignMatch.rawValue else {
            return nil
        }

        var offset = 1

        // Match ID
        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""
        offset += matchIdLength

        // Player 1 name
        guard offset < data.count else { return nil }
        let p1Length = Int(data[offset])
        offset += 1
        guard offset + p1Length <= data.count else { return nil }
        let player1Name = String(data: data[offset..<offset+p1Length], encoding: .utf8) ?? ""
        offset += p1Length

        // Player 2 name
        guard offset < data.count else { return nil }
        let p2Length = Int(data[offset])
        offset += 1
        guard offset + p2Length <= data.count else { return nil }
        let player2Name = String(data: data[offset..<offset+p2Length], encoding: .utf8) ?? ""
        offset += p2Length

        // Config bytes
        guard offset + 4 <= data.count else { return nil }
        let generation = data[offset]
        let matchType = data[offset + 1]
        let bestOf = data[offset + 2]
        let ownFinishEnabled = data[offset + 3] == 0x01

        return AssignMatchMessage(
            matchId: matchId,
            player1Name: player1Name,
            player2Name: player2Name,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled
        )
    }
}

// MARK: - Match Accepted Message

/// Sent by scoreboard to confirm receipt of match assignment.
struct MatchAcceptedMessage: TournamentMessage {
    let messageType = TournamentMessageType.matchAccepted
    let matchId: String
    let deviceId: String

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        let deviceIdData = Data(deviceId.utf8)
        data.append(UInt8(deviceIdData.count))
        data.append(deviceIdData)

        return data
    }

    static func decode(from data: Data) -> MatchAcceptedMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.matchAccepted.rawValue else {
            return nil
        }

        var offset = 1

        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""
        offset += matchIdLength

        guard offset < data.count else { return nil }
        let deviceIdLength = Int(data[offset])
        offset += 1
        guard offset + deviceIdLength <= data.count else { return nil }
        let deviceId = String(data: data[offset..<offset+deviceIdLength], encoding: .utf8) ?? ""

        return MatchAcceptedMessage(matchId: matchId, deviceId: deviceId)
    }
}

// MARK: - Match Unassigned Message

/// Sent by master to notify a scoreboard that their assigned match has been unassigned.
struct MatchUnassignedMessage: TournamentMessage {
    let messageType = TournamentMessageType.matchUnassigned
    let matchId: String
    let reason: String?

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        if let reason = reason {
            let reasonData = Data(reason.utf8)
            data.append(UInt8(reasonData.count))
            data.append(reasonData)
        } else {
            data.append(0x00)
        }

        return data
    }

    static func decode(from data: Data) -> MatchUnassignedMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.matchUnassigned.rawValue else {
            return nil
        }

        var offset = 1

        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""
        offset += matchIdLength

        var reason: String? = nil
        if offset < data.count {
            let reasonLength = Int(data[offset])
            offset += 1
            if reasonLength > 0 && offset + reasonLength <= data.count {
                reason = String(data: data[offset..<offset+reasonLength], encoding: .utf8)
            }
        }

        return MatchUnassignedMessage(matchId: matchId, reason: reason)
    }
}

// MARK: - Submit Score Message

/// Sent by scoreboard to submit final match result.
struct SubmitScoreMessage: TournamentMessage {
    let messageType = TournamentMessageType.submitScore
    let matchId: String
    let deviceId: String        // Scoreboard device ID that scored this match
    let winner: String          // Player name of winner
    let player1FinalScore: UInt8
    let player2FinalScore: UInt8
    let player1SetWins: UInt8
    let player2SetWins: UInt8
    let historyJson: String     // JSON-encoded match history

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        // Match ID
        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        // Device ID
        let deviceIdData = Data(deviceId.utf8)
        data.append(UInt8(deviceIdData.count))
        data.append(deviceIdData)

        // Winner
        let winnerData = Data(winner.utf8)
        data.append(UInt8(winnerData.count))
        data.append(winnerData)

        // Scores (4 bytes)
        data.append(player1FinalScore)
        data.append(player2FinalScore)
        data.append(player1SetWins)
        data.append(player2SetWins)

        // History (2-byte length prefix for potentially large JSON)
        let historyData = Data(historyJson.utf8)
        let historyLength = UInt16(historyData.count)
        data.append(UInt8(historyLength >> 8))
        data.append(UInt8(historyLength & 0xFF))
        data.append(historyData)

        return data
    }

    static func decode(from data: Data) -> SubmitScoreMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.submitScore.rawValue else {
            return nil
        }

        var offset = 1

        // Match ID
        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""
        offset += matchIdLength

        // Device ID
        guard offset < data.count else { return nil }
        let deviceIdLength = Int(data[offset])
        offset += 1
        guard offset + deviceIdLength <= data.count else { return nil }
        let deviceId = String(data: data[offset..<offset+deviceIdLength], encoding: .utf8) ?? ""
        offset += deviceIdLength

        // Winner
        guard offset < data.count else { return nil }
        let winnerLength = Int(data[offset])
        offset += 1
        guard offset + winnerLength <= data.count else { return nil }
        let winner = String(data: data[offset..<offset+winnerLength], encoding: .utf8) ?? ""
        offset += winnerLength

        // Scores
        guard offset + 4 <= data.count else { return nil }
        let p1Score = data[offset]
        let p2Score = data[offset + 1]
        let p1Sets = data[offset + 2]
        let p2Sets = data[offset + 3]
        offset += 4

        // History
        guard offset + 2 <= data.count else { return nil }
        let historyLength = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2
        guard offset + historyLength <= data.count else { return nil }
        let historyJson = String(data: data[offset..<offset+historyLength], encoding: .utf8) ?? "[]"

        return SubmitScoreMessage(
            matchId: matchId,
            deviceId: deviceId,
            winner: winner,
            player1FinalScore: p1Score,
            player2FinalScore: p2Score,
            player1SetWins: p1Sets,
            player2SetWins: p2Sets,
            historyJson: historyJson
        )
    }
}

// MARK: - Approve Score Message

/// Sent by master to approve a score submission.
struct ApproveScoreMessage: TournamentMessage {
    let messageType = TournamentMessageType.approveScore
    let matchId: String

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        return data
    }

    static func decode(from data: Data) -> ApproveScoreMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.approveScore.rawValue else {
            return nil
        }

        var offset = 1
        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""

        return ApproveScoreMessage(matchId: matchId)
    }
}

// MARK: - Reject Score Message

/// Sent by master to reject a score submission.
struct RejectScoreMessage: TournamentMessage {
    let messageType = TournamentMessageType.rejectScore
    let matchId: String
    let reason: String?

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        let matchIdData = Data(matchId.utf8)
        data.append(UInt8(matchIdData.count))
        data.append(matchIdData)

        if let reason = reason {
            let reasonData = Data(reason.utf8)
            data.append(UInt8(reasonData.count))
            data.append(reasonData)
        } else {
            data.append(0x00)
        }

        return data
    }

    static func decode(from data: Data) -> RejectScoreMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.rejectScore.rawValue else {
            return nil
        }

        var offset = 1
        guard offset < data.count else { return nil }
        let matchIdLength = Int(data[offset])
        offset += 1
        guard offset + matchIdLength <= data.count else { return nil }
        let matchId = String(data: data[offset..<offset+matchIdLength], encoding: .utf8) ?? ""
        offset += matchIdLength

        var reason: String? = nil
        if offset < data.count {
            let reasonLength = Int(data[offset])
            offset += 1
            if reasonLength > 0 && offset + reasonLength <= data.count {
                reason = String(data: data[offset..<offset+reasonLength], encoding: .utf8)
            }
        }

        return RejectScoreMessage(matchId: matchId, reason: reason)
    }
}

// MARK: - Room Closed Message

/// Sent by master to notify scoreboards that the room/tournament has been closed.
struct RoomClosedMessage: TournamentMessage {
    let messageType = TournamentMessageType.leaveRoom
    let reason: String?

    func encode() -> Data {
        var data = Data()
        data.append(messageType.rawValue)

        if let reason = reason {
            let reasonData = Data(reason.utf8)
            data.append(UInt8(reasonData.count))
            data.append(reasonData)
        } else {
            data.append(0x00)
        }

        return data
    }

    static func decode(from data: Data) -> RoomClosedMessage? {
        guard data.count >= 1,
              data[0] == TournamentMessageType.leaveRoom.rawValue else {
            return nil
        }

        var reason: String? = nil
        if data.count > 1 {
            let reasonLength = Int(data[1])
            if reasonLength > 0 && data.count >= 2 + reasonLength {
                reason = String(data: data[2..<2+reasonLength], encoding: .utf8)
            }
        }

        return RoomClosedMessage(reason: reason)
    }
}

// MARK: - Tournament Message Factory

/// Factory for decoding tournament messages from raw data.
enum TournamentMessageFactory {

    /// Decodes a tournament message from raw data.
    /// - Parameter data: The raw message data (after HMAC validation)
    /// - Returns: The decoded message, or nil if invalid
    static func decode(from data: Data) -> (any TournamentMessage)? {
        guard let firstByte = data.first,
              let msgType = TournamentMessageType(rawValue: firstByte) else {
            return nil
        }

        switch msgType {
        case .joinRoom:
            return JoinRoomMessage.decode(from: data)
        case .roomJoined:
            return RoomJoinedMessage.decode(from: data)
        case .leaveRoom:
            return RoomClosedMessage.decode(from: data)
        case .assignMatch:
            return AssignMatchMessage.decode(from: data)
        case .matchAccepted:
            return MatchAcceptedMessage.decode(from: data)
        case .matchUnassigned:
            return MatchUnassignedMessage.decode(from: data)
        case .submitScore:
            return SubmitScoreMessage.decode(from: data)
        case .approveScore:
            return ApproveScoreMessage.decode(from: data)
        case .rejectScore:
            return RejectScoreMessage.decode(from: data)
        case .tournamentUpdate:
            return nil // TODO: Implement when tournament models are ready
        case .requestState:
            return nil // TODO: Implement
        }
    }
}
