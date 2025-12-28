//
// TournamentRoomManager.swift
// bitchat
//
// Manages tournament room state and message authentication.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Delegate protocol for tournament room events.
protocol TournamentRoomDelegate: AnyObject {
    func roomDidJoin(roomCode: RoomCode)
    func roomDidLeave()
    func roomJoinFailed(error: TournamentRoomError)
    func didReceiveTournamentMessage(_ message: any TournamentMessage, from peerID: PeerID)
}

/// Errors related to tournament room operations.
enum TournamentRoomError: Error, LocalizedError {
    case notInRoom
    case alreadyInRoom
    case invalidRoomCode
    case authenticationFailed
    case roomNotFound
    case notMaster
    case notScoreboard

    var errorDescription: String? {
        switch self {
        case .notInRoom:
            return "Not currently in a tournament room"
        case .alreadyInRoom:
            return "Already in a tournament room"
        case .invalidRoomCode:
            return "Invalid room code format"
        case .authenticationFailed:
            return "Room authentication failed"
        case .roomNotFound:
            return "Tournament room not found"
        case .notMaster:
            return "Only the tournament master can perform this action"
        case .notScoreboard:
            return "Only scoreboard devices can perform this action"
        }
    }
}

/// Manages tournament room membership and message authentication.
/// Handles joining/leaving rooms and filtering messages by HMAC validation.
@MainActor
final class TournamentRoomManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TournamentRoomManager()

    // MARK: - Published Properties

    /// The current room code, if in a room
    @Published private(set) var currentRoomCode: RoomCode?

    /// The device mode (master or scoreboard)
    @Published var deviceMode: DeviceMode = .scoreboard

    /// Whether currently in a room
    @Published private(set) var isInRoom: Bool = false

    /// Device ID for this device
    @Published var deviceId: String = ""

    /// Device name for this device
    @Published var deviceName: String = ""

    /// Whether the scoreboard has an active match in progress.
    /// Updated by ScoreboardCoordinator when match state changes.
    @Published var hasActiveMatch: Bool = false

    /// The currently active match assignment (for persistence across view dismissals).
    /// Only used in scoreboard mode.
    @Published var activeMatchAssignment: AssignMatchMessage? = nil

    // MARK: - Private Properties

    private let authService = RoomAuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()

    /// Delegate for room events
    weak var delegate: TournamentRoomDelegate?

    // MARK: - Initialization

    private init() {
        // Generate a unique device ID if not already set
        if deviceId.isEmpty {
            deviceId = generateDeviceId()
        }

        // Use device name or generate one
        if deviceName.isEmpty {
            deviceName = UIDevice.current.name
        }

        // Load saved room state
        loadSavedState()
    }

    // MARK: - Room Management

    /// Creates a new tournament room with a random code.
    /// Only valid for master mode.
    /// - Returns: The generated room code
    func createRoom() throws -> RoomCode {
        guard !isInRoom else {
            throw TournamentRoomError.alreadyInRoom
        }

        let roomCode = RoomCode.generate()
        currentRoomCode = roomCode
        isInRoom = true
        deviceMode = .master

        saveState()
        delegate?.roomDidJoin(roomCode: roomCode)

        return roomCode
    }

    /// Joins an existing tournament room with the given code.
    /// - Parameter codeString: The 6-digit room code
    func joinRoom(codeString: String) throws {
        guard !isInRoom else {
            throw TournamentRoomError.alreadyInRoom
        }

        guard let roomCode = RoomCode(code: codeString) else {
            throw TournamentRoomError.invalidRoomCode
        }

        currentRoomCode = roomCode
        isInRoom = true
        deviceMode = .scoreboard

        saveState()
        delegate?.roomDidJoin(roomCode: roomCode)
    }

    /// Leaves the current room.
    func leaveRoom() {
        currentRoomCode = nil
        isInRoom = false

        saveState()
        delegate?.roomDidLeave()
    }

    /// Clears the active match assignment (when match is completed, abandoned, or room closed).
    func clearActiveMatch() {
        activeMatchAssignment = nil
        hasActiveMatch = false
        saveState()
    }

    /// Sets up the room as Master with a specific code.
    /// Used when creating a tournament with a pre-generated code.
    /// - Parameter code: The room code string
    func setupMasterRoom(code: String) {
        guard let roomCode = RoomCode(code: code) else { return }

        currentRoomCode = roomCode
        isInRoom = true
        deviceMode = .master

        saveState()
        delegate?.roomDidJoin(roomCode: roomCode)
    }

    // MARK: - Message Handling

    /// Processes an incoming room message packet.
    /// Validates the HMAC signature and extracts the tournament message.
    /// - Parameters:
    ///   - packet: The raw packet data
    ///   - peerID: The peer that sent the packet
    /// - Returns: The decoded tournament message if valid
    func processIncomingPacket(_ packet: Data, from peerID: PeerID) -> (any TournamentMessage)? {
        guard let roomCode = currentRoomCode else {
            // Not in a room, ignore room messages
            return nil
        }

        // Extract and validate payload
        guard let payload = authService.extractPayload(from: packet, roomCode: roomCode) else {
            // Invalid HMAC, ignore this message
            return nil
        }

        // Decode the tournament message
        guard let message = TournamentMessageFactory.decode(from: payload) else {
            return nil
        }

        // Notify delegate
        delegate?.didReceiveTournamentMessage(message, from: peerID)

        return message
    }

    /// Creates a signed room message packet.
    /// - Parameter message: The tournament message to send
    /// - Returns: The signed packet data, or nil if not in a room
    func createSignedPacket(for message: any TournamentMessage) -> Data? {
        guard let roomCode = currentRoomCode else {
            return nil
        }

        let payload = message.encode()
        return authService.createSignedPacket(payload: payload, roomCode: roomCode)
    }

    /// Validates if a packet has a valid HMAC for the current room.
    /// Use this for quick filtering before full processing.
    /// - Parameter packet: The raw packet data
    /// - Returns: true if the packet has a valid signature
    func isValidPacket(_ packet: Data) -> Bool {
        guard let roomCode = currentRoomCode else {
            return false
        }

        return authService.extractPayload(from: packet, roomCode: roomCode) != nil
    }

    // MARK: - Persistence

    private let roomCodeKey = "beyscore.roomCode"
    private let deviceModeKey = "beyscore.deviceMode"
    private let deviceIdKey = "beyscore.deviceId"
    private let deviceNameKey = "beyscore.deviceName"
    private let activeMatchKey = "beyscore.activeMatch"

    func saveState() {
        let defaults = UserDefaults.standard

        if let roomCode = currentRoomCode {
            defaults.set(roomCode.code, forKey: roomCodeKey)
            defaults.set(deviceMode.rawValue, forKey: deviceModeKey)
        } else {
            defaults.removeObject(forKey: roomCodeKey)
            defaults.removeObject(forKey: deviceModeKey)
        }

        defaults.set(deviceId, forKey: deviceIdKey)
        defaults.set(deviceName, forKey: deviceNameKey)

        // Save active match assignment
        if let assignment = activeMatchAssignment,
           let data = try? JSONEncoder().encode(assignment) {
            defaults.set(data, forKey: activeMatchKey)
        } else {
            defaults.removeObject(forKey: activeMatchKey)
        }
    }

    private func loadSavedState() {
        let defaults = UserDefaults.standard

        if let savedDeviceId = defaults.string(forKey: deviceIdKey) {
            deviceId = savedDeviceId
        }

        if let savedDeviceName = defaults.string(forKey: deviceNameKey) {
            deviceName = savedDeviceName
        }

        if let savedCode = defaults.string(forKey: roomCodeKey),
           let roomCode = RoomCode(code: savedCode),
           let modeRaw = defaults.object(forKey: deviceModeKey) as? UInt8,
           let mode = DeviceMode(rawValue: modeRaw) {
            currentRoomCode = roomCode
            deviceMode = mode
            isInRoom = true
        }

        // Load active match assignment
        if let data = defaults.data(forKey: activeMatchKey),
           let assignment = try? JSONDecoder().decode(AssignMatchMessage.self, from: data) {
            activeMatchAssignment = assignment
        }
    }

    private func generateDeviceId() -> String {
        // Generate a unique device ID
        let uuid = UUID().uuidString.prefix(16)
        return String(uuid)
    }

    // MARK: - Mode Helpers

    /// Whether this device is the tournament master.
    var isMaster: Bool {
        return isInRoom && deviceMode == .master
    }

    /// Whether this device is a scoreboard.
    var isScoreboard: Bool {
        return isInRoom && deviceMode == .scoreboard
    }

    /// Ensures the device is a master, throws otherwise.
    func requireMaster() throws {
        guard isMaster else {
            throw TournamentRoomError.notMaster
        }
    }

    /// Ensures the device is a scoreboard, throws otherwise.
    func requireScoreboard() throws {
        guard isScoreboard else {
            throw TournamentRoomError.notScoreboard
        }
    }
}

// MARK: - UIDevice Extension for Cross-Platform

#if os(iOS)
import UIKit
#else
// For macOS or other platforms
extension TournamentRoomManager {
    struct UIDevice {
        static var current: UIDevice { UIDevice() }
        var name: String { ProcessInfo.processInfo.hostName }
    }
}
#endif
