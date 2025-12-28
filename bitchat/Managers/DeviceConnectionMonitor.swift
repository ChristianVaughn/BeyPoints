//
// DeviceConnectionMonitor.swift
// bitchat
//
// Monitors connected scoreboards and handles disconnections.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Monitors scoreboard connections and handles disconnections during matches.
@MainActor
final class DeviceConnectionMonitor: ObservableObject {

    static let shared = DeviceConnectionMonitor()

    // MARK: - Published State

    @Published private(set) var connectedDevices: [String: DeviceConnectionInfo] = [:]
    @Published private(set) var interruptedMatches: [UUID] = []

    // MARK: - Configuration

    private let heartbeatInterval: TimeInterval = 10.0
    private let connectionTimeout: TimeInterval = 30.0

    // MARK: - Dependencies

    private let tournamentManager = TournamentManager.shared
    private let messageHandler = TournamentMessageHandler.shared

    // MARK: - State

    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
        startHeartbeatMonitoring()
    }

    private func setupObservers() {
        // Observe scoreboard join events via NotificationCenter
        NotificationCenter.default.publisher(for: .scoreboardJoined)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let deviceId = notification.userInfo?["deviceId"] as? String,
                   let deviceName = notification.userInfo?["deviceName"] as? String {
                    self?.handleDeviceConnected(
                        deviceId: deviceId,
                        deviceName: deviceName
                    )
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Device Tracking

    /// Called when a device connects or sends a heartbeat.
    func handleDeviceConnected(deviceId: String, deviceName: String) {
        let info = DeviceConnectionInfo(
            deviceId: deviceId,
            deviceName: deviceName,
            lastSeen: Date(),
            status: .connected
        )
        connectedDevices[deviceId] = info

        // If this device had an interrupted match, it can resume
        checkForResumableMatches(deviceId: deviceId)
    }

    /// Called when we receive any message from a device (updates last seen).
    func handleDeviceHeartbeat(deviceId: String) {
        if var info = connectedDevices[deviceId] {
            info.lastSeen = Date()
            info.status = .connected
            connectedDevices[deviceId] = info
        }
    }

    /// Manually marks a device as disconnected.
    func handleDeviceDisconnected(deviceId: String) {
        guard var info = connectedDevices[deviceId] else { return }

        info.status = .disconnected
        info.disconnectedAt = Date()
        connectedDevices[deviceId] = info

        // Handle any matches assigned to this device
        handleMatchInterruption(deviceId: deviceId)
    }

    // MARK: - Match Interruption

    private func handleMatchInterruption(deviceId: String) {
        guard let tournament = tournamentManager.currentTournament else { return }

        // Find matches assigned to this device that are in progress
        let affectedMatches = tournament.matches.filter { match in
            match.assignedDeviceId == deviceId &&
            (match.status == .inProgress || match.status == .assigned)
        }

        for match in affectedMatches {
            // Mark match as interrupted
            interruptedMatches.append(match.id)

            // Update match status (can be reassigned)
            tournamentManager.unassignMatch(matchId: match.id)

            // Notify about the interruption
            NotificationCenter.default.post(
                name: .matchInterrupted,
                object: nil,
                userInfo: [
                    "matchId": match.id,
                    "deviceId": deviceId,
                    "match": match
                ]
            )
        }
    }

    private func checkForResumableMatches(deviceId: String) {
        // Check if this device had any interrupted matches
        guard let tournament = tournamentManager.currentTournament else { return }

        let previouslyAssigned = tournament.matches.filter { match in
            interruptedMatches.contains(match.id) &&
            match.status == .pending  // Was unassigned due to disconnect
        }

        // Notify about potential resumable matches
        for match in previouslyAssigned {
            NotificationCenter.default.post(
                name: .matchResumable,
                object: nil,
                userInfo: [
                    "matchId": match.id,
                    "deviceId": deviceId,
                    "match": match
                ]
            )
        }
    }

    // MARK: - Heartbeat Monitoring

    private func startHeartbeatMonitoring() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDeviceConnections()
            }
        }
    }

    private func checkDeviceConnections() {
        let now = Date()

        for (deviceId, info) in connectedDevices {
            let timeSinceLastSeen = now.timeIntervalSince(info.lastSeen)

            if timeSinceLastSeen > connectionTimeout && info.status == .connected {
                handleDeviceDisconnected(deviceId: deviceId)
            }
        }
    }

    /// Stops monitoring (call when leaving room).
    func stopMonitoring() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        connectedDevices.removeAll()
        interruptedMatches.removeAll()
    }

    // MARK: - Match Reassignment

    /// Clears the interrupted flag for a match (when successfully reassigned).
    func clearInterruption(matchId: UUID) {
        interruptedMatches.removeAll { $0 == matchId }
    }

    /// Checks if a match was interrupted and can be reassigned.
    func wasInterrupted(matchId: UUID) -> Bool {
        interruptedMatches.contains(matchId)
    }

    /// Gets devices available for assignment.
    func getAvailableDevices() -> [DeviceConnectionInfo] {
        connectedDevices.values.filter { $0.status == .connected }
    }
}

// MARK: - Supporting Types

struct DeviceConnectionInfo: Identifiable {
    let deviceId: String
    let deviceName: String
    var lastSeen: Date
    var status: DeviceStatus
    var disconnectedAt: Date?

    var id: String { deviceId }

    var timeSinceLastSeen: TimeInterval {
        Date().timeIntervalSince(lastSeen)
    }

    var isStale: Bool {
        timeSinceLastSeen > 30.0
    }
}

enum DeviceStatus: String {
    case connected
    case disconnected
    case reconnecting

    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .reconnecting: return "Reconnecting"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let matchInterrupted = Notification.Name("matchInterrupted")
    static let matchResumable = Notification.Name("matchResumable")
}
