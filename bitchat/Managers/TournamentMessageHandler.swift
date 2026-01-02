//
// TournamentMessageHandler.swift
// bitchat
//
// Handles sending and receiving tournament messages over BLE mesh.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Handles tournament message routing between Master and Scoreboard devices.
/// Integrates with BLEService for transport and uses HMAC for room authentication.
@MainActor
final class TournamentMessageHandler: ObservableObject {

    // MARK: - Singleton

    static let shared = TournamentMessageHandler()

    // MARK: - Dependencies

    private let authService = RoomAuthenticationService.shared
    private let roomManager = TournamentRoomManager.shared
    private let tournamentManager = TournamentManager.shared

    // MARK: - Published State

    @Published private(set) var lastError: TournamentMessageError?
    @Published private(set) var isProcessing = false

    // MARK: - Callbacks

    /// Called when a match is assigned to this scoreboard device.
    var onMatchAssigned: ((AssignMatchMessage) -> Void)?

    /// Called when a score is approved by Master.
    var onScoreApproved: ((UUID) -> Void)?

    /// Called when a score is rejected by Master.
    var onScoreRejected: ((UUID, String?) -> Void)?

    /// Called when room join is confirmed.
    var onRoomJoined: ((Bool, String?) -> Void)?

    /// Called when the room is closed by Master (Scoreboard mode).
    var onRoomClosed: ((String?) -> Void)?

    /// Called when the current match is unassigned by Master (Scoreboard mode).
    var onMatchUnassigned: ((UUID, String?) -> Void)?

    // MARK: - Private Properties

    private var bleService: BLEService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    /// Sets the BLE service for sending messages.
    func setBLEService(_ service: BLEService) {
        self.bleService = service
    }

    /// Gets the local device ID for message sending.
    var deviceId: String {
        bleService?.myPeerID.id ?? UUID().uuidString
    }

    /// Gets the local device name.
    var deviceName: String {
        bleService?.myNickname ?? "Unknown Device"
    }

    // MARK: - Receiving Messages

    /// Handles an incoming roomMessage packet.
    /// Called by BitchatDelegate when a roomMessage is received.
    func handleIncomingPacket(_ packet: BitchatPacket) {
        print("[BeyScore] handleIncomingPacket called, type=\(packet.type)")
        guard packet.type == MessageType.roomMessage.rawValue else {
            print("[BeyScore] handleIncomingPacket: not a roomMessage, ignoring")
            return
        }

        // Get current room code for validation
        guard let roomCode = roomManager.currentRoomCode else {
            print("[BeyScore] handleIncomingPacket: not in a room, ignoring")
            return
        }

        print("[BeyScore] handleIncomingPacket: validating HMAC for room \(roomCode.code)")

        // Extract and validate payload
        guard let payload = authService.extractPayload(from: packet.payload, roomCode: roomCode) else {
            print("[BeyScore] handleIncomingPacket: HMAC validation FAILED")
            lastError = .invalidSignature
            return
        }

        print("[BeyScore] handleIncomingPacket: HMAC valid, decoding message...")

        // Decode the tournament message
        guard let message = TournamentMessageFactory.decode(from: payload) else {
            print("[BeyScore] handleIncomingPacket: message decoding FAILED")
            lastError = .decodingFailed
            return
        }

        print("[BeyScore] handleIncomingPacket: received \(type(of: message))")

        // Route to appropriate handler based on message type
        routeMessage(message)
    }

    // MARK: - Message Routing

    private func routeMessage(_ message: any TournamentMessage) {
        switch message {
        case let msg as JoinRoomMessage:
            handleJoinRoom(msg)
        case let msg as RoomJoinedMessage:
            handleRoomJoined(msg)
        case let msg as AssignMatchMessage:
            handleAssignMatch(msg)
        case let msg as MatchAcceptedMessage:
            handleMatchAccepted(msg)
        case let msg as SubmitScoreMessage:
            handleSubmitScore(msg)
        case let msg as ApproveScoreMessage:
            handleApproveScore(msg)
        case let msg as RejectScoreMessage:
            handleRejectScore(msg)
        case let msg as RoomClosedMessage:
            handleRoomClosed(msg)
        case let msg as MatchUnassignedMessage:
            handleMatchUnassigned(msg)
        default:
            break
        }
    }

    // MARK: - Master Mode Handlers

    /// Handles a join room request (Master mode).
    private func handleJoinRoom(_ message: JoinRoomMessage) {
        print("[BeyScore] handleJoinRoom: deviceMode=\(roomManager.deviceMode), deviceId=\(message.deviceId), deviceName=\(message.deviceName)")
        guard roomManager.deviceMode == .master else {
            print("[BeyScore] handleJoinRoom: NOT master, ignoring")
            return
        }

        print("[BeyScore] handleJoinRoom: registering scoreboard...")
        // Register the scoreboard
        tournamentManager.registerScoreboard(
            deviceId: message.deviceId,
            deviceName: message.deviceName
        )
        print("[BeyScore] handleJoinRoom: scoreboard registered. Total scoreboards: \(tournamentManager.connectedScoreboards.count)")

        // Send confirmation
        let response = RoomJoinedMessage(
            success: true,
            tournamentName: tournamentManager.currentTournament?.name,
            errorMessage: nil
        )
        sendTournamentMessage(response)
    }

    /// Handles a match accepted acknowledgment (Master mode).
    private func handleMatchAccepted(_ message: MatchAcceptedMessage) {
        guard roomManager.deviceMode == .master else { return }

        // Update scoreboard status to indicate match is being scored
        guard let matchId = UUID(uuidString: message.matchId) else { return }

        // Update tournament via manager
        tournamentManager.startMatch(matchId: matchId)

        // Post notification for observers
        NotificationCenter.default.post(
            name: .matchAccepted,
            object: nil,
            userInfo: [
                "matchId": matchId,
                "deviceId": message.deviceId
            ]
        )
    }

    /// Handles a score submission (Master mode).
    private func handleSubmitScore(_ message: SubmitScoreMessage) {
        guard roomManager.deviceMode == .master else { return }

        guard let matchId = UUID(uuidString: message.matchId) else { return }

        // Decode history from JSON
        var history: [HistoryEntry] = []
        if let historyData = message.historyJson.data(using: .utf8) {
            history = (try? JSONDecoder().decode([HistoryEntry].self, from: historyData)) ?? []
        }

        // Create pending submission
        let submission = PendingScoreSubmission(
            matchId: matchId,
            deviceId: message.deviceId,  // Use the sender's device ID from the message
            winner: message.winner,
            player1FinalScore: Int(message.player1FinalScore),
            player2FinalScore: Int(message.player2FinalScore),
            player1SetWins: Int(message.player1SetWins),
            player2SetWins: Int(message.player2SetWins),
            matchHistory: history
        )

        tournamentManager.receiveScoreSubmission(submission)
    }

    // MARK: - Scoreboard Mode Handlers

    /// Handles room joined confirmation (Scoreboard mode).
    private func handleRoomJoined(_ message: RoomJoinedMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        onRoomJoined?(message.success, message.success ? message.tournamentName : message.errorMessage)
    }

    /// Handles match assignment (Scoreboard mode).
    private func handleAssignMatch(_ message: AssignMatchMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        // Notify UI of assignment
        onMatchAssigned?(message)

        // Send acceptance
        let acceptance = MatchAcceptedMessage(
            matchId: message.matchId,
            deviceId: deviceId
        )
        sendTournamentMessage(acceptance)
    }

    /// Handles score approval (Scoreboard mode).
    private func handleApproveScore(_ message: ApproveScoreMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        if let matchId = UUID(uuidString: message.matchId) {
            onScoreApproved?(matchId)
        }
    }

    /// Handles score rejection (Scoreboard mode).
    private func handleRejectScore(_ message: RejectScoreMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        if let matchId = UUID(uuidString: message.matchId) {
            onScoreRejected?(matchId, message.reason)
        }
    }

    /// Handles room closed message (Scoreboard mode).
    private func handleRoomClosed(_ message: RoomClosedMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        print("[BeyScore] handleRoomClosed: room was closed by Master, reason=\(message.reason ?? "none")")
        onRoomClosed?(message.reason)
    }

    /// Handles match unassigned message (Scoreboard mode).
    private func handleMatchUnassigned(_ message: MatchUnassignedMessage) {
        guard roomManager.deviceMode == .scoreboard else { return }

        print("[BeyScore] handleMatchUnassigned: match unassigned by Master, matchId=\(message.matchId), reason=\(message.reason ?? "none")")
        if let matchId = UUID(uuidString: message.matchId) {
            onMatchUnassigned?(matchId, message.reason)
        }
    }

    // MARK: - Sending Messages

    /// Sends a tournament message to all devices in the room.
    func sendTournamentMessage(_ message: any TournamentMessage) {
        guard let roomCode = roomManager.currentRoomCode else {
            print("[BeyScore] sendTournamentMessage FAILED: not in room")
            lastError = .notInRoom
            return
        }

        guard let bleService = bleService else {
            print("[BeyScore] sendTournamentMessage FAILED: bleService is nil")
            lastError = .bleNotAvailable
            return
        }

        print("[BeyScore] sendTournamentMessage: sending \(type(of: message)) to room \(roomCode.code)")

        // Encode the message
        let payload = message.encode()

        // Sign with room code
        let signedPayload = authService.createSignedPacket(payload: payload, roomCode: roomCode)

        // Create packet
        let packet = BitchatPacket(
            type: MessageType.roomMessage.rawValue,
            ttl: 3, // Limited hops for tournament messages
            senderID: bleService.myPeerID,
            payload: signedPayload
        )

        // Send via BLE
        bleService.sendPacket(packet)
        print("[BeyScore] sendTournamentMessage: packet sent via BLE")
    }

    // MARK: - Scoreboard Actions

    /// Sends a join room request (Scoreboard mode).
    func sendJoinRoom() {
        print("[BeyScore] sendJoinRoom called. deviceId=\(deviceId), deviceName=\(deviceName)")
        let message = JoinRoomMessage(
            deviceId: deviceId,
            deviceName: deviceName,
            mode: .scoreboard
        )
        sendTournamentMessage(message)
    }

    /// Sends a score submission to Master (Scoreboard mode).
    func submitScore(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        history: [HistoryEntry]
    ) {
        // Encode history to JSON
        let historyJson: String
        if let jsonData = try? JSONEncoder().encode(history),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            historyJson = jsonString
        } else {
            historyJson = "[]"
        }

        let message = SubmitScoreMessage(
            matchId: matchId.uuidString,
            deviceId: deviceId,  // Include this scoreboard's device ID
            winner: winner,
            player1FinalScore: UInt8(min(255, player1Score)),
            player2FinalScore: UInt8(min(255, player2Score)),
            player1SetWins: UInt8(min(255, player1SetWins)),
            player2SetWins: UInt8(min(255, player2SetWins)),
            historyJson: historyJson
        )
        sendTournamentMessage(message)
    }

    // MARK: - Master Actions

    /// Sends a match assignment to a scoreboard (Master mode).
    func assignMatchToDevice(
        match: TournamentMatch,
        deviceId: String,
        config: MatchConfiguration
    ) {
        let message = AssignMatchMessage(
            matchId: match.id.uuidString,
            player1Name: match.player1Name ?? "TBD",
            player2Name: match.player2Name ?? "TBD",
            generation: config.generation.byteValue,
            matchType: config.matchType.byteValue,
            bestOf: config.bestOf.byteValue,
            ownFinishEnabled: config.ownFinishEnabled
        )
        sendTournamentMessage(message)
    }

    /// Sends score approval to a scoreboard (Master mode).
    func approveScore(matchId: UUID) {
        let message = ApproveScoreMessage(matchId: matchId.uuidString)
        sendTournamentMessage(message)
        tournamentManager.approveScore(matchId: matchId)
    }

    /// Sends score rejection to a scoreboard (Master mode).
    func rejectScore(matchId: UUID, reason: String?) {
        let message = RejectScoreMessage(matchId: matchId.uuidString, reason: reason)
        sendTournamentMessage(message)
        tournamentManager.rejectScore(matchId: matchId, reason: reason)
    }

    /// Broadcasts the current tournament state to all connected devices (Master mode).
    func broadcastTournamentUpdate() {
        guard roomManager.deviceMode == .master else { return }
        guard tournamentManager.currentTournament != nil else { return }

        // For now, this is a stub. Full implementation would encode
        // and send a TOURNAMENT_UPDATE message (0x48) with the full state.
        // Connected scoreboards would receive this to sync their view.
    }

    /// Broadcasts room closed to all connected scoreboards (Master mode).
    /// Call this before ending a tournament to notify connected devices.
    func broadcastRoomClosed(reason: String? = nil) {
        guard roomManager.deviceMode == .master else { return }

        print("[BeyScore] broadcastRoomClosed: notifying all scoreboards, reason=\(reason ?? "Tournament ended")")
        let message = RoomClosedMessage(reason: reason ?? "Tournament ended")
        sendTournamentMessage(message)
    }

    /// Broadcasts match unassignment to all connected scoreboards (Master mode).
    /// This notifies the scoreboard that was assigned the match to clear their state.
    func broadcastMatchUnassigned(matchId: UUID, reason: String? = nil) {
        guard roomManager.deviceMode == .master else { return }

        print("[BeyScore] broadcastMatchUnassigned: matchId=\(matchId), reason=\(reason ?? "Unassigned by master")")
        let message = MatchUnassignedMessage(matchId: matchId.uuidString, reason: reason)
        sendTournamentMessage(message)
    }
}

// MARK: - Error Types

enum TournamentMessageError: Error, LocalizedError {
    case notInRoom
    case invalidSignature
    case decodingFailed
    case sendFailed
    case bleNotAvailable

    var errorDescription: String? {
        switch self {
        case .notInRoom:
            return "Not currently in a tournament room"
        case .invalidSignature:
            return "Message signature validation failed"
        case .decodingFailed:
            return "Failed to decode tournament message"
        case .sendFailed:
            return "Failed to send tournament message"
        case .bleNotAvailable:
            return "Bluetooth service not available"
        }
    }
}

// MARK: - Extensions for Byte Value Access

extension BeybladeGeneration {
    var byteValue: UInt8 {
        switch self {
        case .x: return 0x01
        case .burst: return 0x02
        case .metalFight: return 0x03
        case .plastics: return 0x04
        }
    }

    init?(byteValue: UInt8) {
        switch byteValue {
        case 0x01: self = .x
        case 0x02: self = .burst
        case 0x03: self = .metalFight
        case 0x04: self = .plastics
        default: return nil
        }
    }
}

extension MatchType {
    var byteValue: UInt8 {
        switch self {
        case .points3: return 3
        case .points4: return 4
        case .points5: return 5
        case .points7: return 7
        case .noLimit: return 0
        }
    }

    init?(byteValue: UInt8) {
        switch byteValue {
        case 3: self = .points3
        case 4: self = .points4
        case 5: self = .points5
        case 7: self = .points7
        case 0: self = .noLimit
        default: return nil
        }
    }
}

extension BestOf {
    var byteValue: UInt8 {
        switch self {
        case .none: return 0
        case .bestOf3: return 3
        case .bestOf5: return 5
        }
    }

    init?(byteValue: UInt8) {
        switch byteValue {
        case 0: self = .none
        case 3: self = .bestOf3
        case 5: self = .bestOf5
        default: return nil
        }
    }
}
