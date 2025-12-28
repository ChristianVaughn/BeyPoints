//
// ReconnectionManager.swift
// bitchat
//
// Handles automatic reconnection and state recovery.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Manages automatic reconnection and state synchronization.
@MainActor
final class ReconnectionManager: ObservableObject {

    static let shared = ReconnectionManager()

    // MARK: - Published State

    @Published private(set) var isReconnecting = false
    @Published private(set) var reconnectAttempts = 0
    @Published private(set) var lastDisconnectTime: Date?
    @Published private(set) var connectionState: ConnectionState = .disconnected

    // MARK: - Configuration

    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    private let reconnectBackoffMultiplier = 1.5

    // MARK: - Dependencies

    private let roomManager = TournamentRoomManager.shared
    private let messageHandler = TournamentMessageHandler.shared

    // MARK: - State

    private var reconnectTask: Task<Void, Never>?
    private var pendingMatchState: PendingMatchState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe BLE connection state changes
        NotificationCenter.default.publisher(for: .bleConnectionStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let isConnected = notification.userInfo?["isConnected"] as? Bool {
                    self?.handleConnectionStateChange(isConnected: isConnected)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Connection State Handling

    private func handleConnectionStateChange(isConnected: Bool) {
        if isConnected {
            connectionState = .connected

            // If we were reconnecting, attempt to rejoin room
            if isReconnecting {
                Task {
                    await attemptRoomRejoin()
                }
            }
        } else {
            lastDisconnectTime = Date()
            connectionState = .disconnected

            // Start reconnection if we were in a room
            if roomManager.isInRoom {
                startReconnection()
            }
        }
    }

    // MARK: - Reconnection Logic

    /// Starts the reconnection process.
    func startReconnection() {
        guard !isReconnecting else { return }

        isReconnecting = true
        reconnectAttempts = 0
        connectionState = .reconnecting

        // Save current match state if in progress
        saveCurrentMatchState()

        reconnectTask = Task {
            await performReconnection()
        }
    }

    /// Cancels ongoing reconnection attempts.
    func cancelReconnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        reconnectAttempts = 0
    }

    private func performReconnection() async {
        while reconnectAttempts < maxReconnectAttempts && !Task.isCancelled {
            reconnectAttempts += 1

            // Calculate delay with exponential backoff
            let delay = reconnectDelay * pow(reconnectBackoffMultiplier, Double(reconnectAttempts - 1))

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if Task.isCancelled { break }

            // Check if connection was restored
            if connectionState == .connected {
                await attemptRoomRejoin()
                break
            }
        }

        if reconnectAttempts >= maxReconnectAttempts {
            connectionState = .failed
        }

        isReconnecting = false
    }

    // MARK: - Room Rejoin

    private func attemptRoomRejoin() async {
        guard let roomCode = roomManager.currentRoomCode else {
            isReconnecting = false
            return
        }

        connectionState = .rejoiningRoom

        // Send join room message
        if roomManager.isMaster {
            // Master just needs to re-announce presence
            // Other devices will re-sync when they reconnect
            await resyncTournamentState()
        } else {
            // Scoreboard needs to rejoin
            messageHandler.sendJoinRoom()
        }

        // Wait for response with timeout
        let rejoined = await waitForRoomJoinConfirmation(timeout: 10.0)

        if rejoined {
            connectionState = .connected
            isReconnecting = false

            // Restore match state if we had one
            await restoreMatchState()
        } else {
            // Retry or fail
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                await attemptRoomRejoin()
            } else {
                connectionState = .failed
                isReconnecting = false
            }
        }
    }

    private func waitForRoomJoinConfirmation(timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            var didResume = false

            // Set up listener for room joined event using roomManager
            let cancellable = roomManager.$isInRoom
                .filter { $0 }
                .first()
                .sink { _ in
                    if !didResume {
                        didResume = true
                        continuation.resume(returning: true)
                    }
                }

            // Timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                cancellable.cancel()
                if !didResume {
                    didResume = true
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - State Preservation

    private func saveCurrentMatchState() {
        // Save current scoring state if match is in progress
        let stateManager = ScoreboardStateManager.shared

        if stateManager.isInMatch,
           let gameState = stateManager.currentGameState,
           let matchId = stateManager.currentMatchId {
            pendingMatchState = PendingMatchState(
                matchId: matchId,
                gameState: gameState,
                savedAt: Date()
            )

            // Persist to disk for crash recovery
            savePendingStateToDisk()
        }
    }

    private func restoreMatchState() async {
        guard let pendingState = pendingMatchState else { return }

        // Check if the match is still valid
        let stateManager = ScoreboardStateManager.shared

        // Restore the game state
        stateManager.restoreGameState(pendingState.gameState)

        pendingMatchState = nil
        clearPendingStateFromDisk()
    }

    private func resyncTournamentState() async {
        // Master broadcasts current tournament state to all scoreboards
        messageHandler.broadcastTournamentUpdate()
    }

    // MARK: - Disk Persistence

    private var pendingStateURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending_match_state.json")
    }

    private func savePendingStateToDisk() {
        guard let state = pendingMatchState else { return }

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: pendingStateURL)
        } catch {
            print("Failed to save pending state: \(error)")
        }
    }

    private func clearPendingStateFromDisk() {
        try? FileManager.default.removeItem(at: pendingStateURL)
    }

    func loadPendingStateFromDisk() {
        guard FileManager.default.fileExists(atPath: pendingStateURL.path) else { return }

        do {
            let data = try Data(contentsOf: pendingStateURL)
            pendingMatchState = try JSONDecoder().decode(PendingMatchState.self, from: data)
        } catch {
            print("Failed to load pending state: \(error)")
            clearPendingStateFromDisk()
        }
    }
}

// MARK: - Supporting Types

enum ConnectionState: String {
    case connected
    case disconnected
    case reconnecting
    case rejoiningRoom
    case failed

    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .reconnecting: return "Reconnecting..."
        case .rejoiningRoom: return "Rejoining room..."
        case .failed: return "Connection failed"
        }
    }

    var isConnected: Bool {
        self == .connected
    }
}

struct PendingMatchState: Codable {
    let matchId: UUID
    let gameState: GameState
    let savedAt: Date

    var isExpired: Bool {
        // Consider state expired after 1 hour
        Date().timeIntervalSince(savedAt) > 3600
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let bleConnectionStateChanged = Notification.Name("bleConnectionStateChanged")
}
