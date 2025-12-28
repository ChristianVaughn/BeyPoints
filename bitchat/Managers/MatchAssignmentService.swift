//
// MatchAssignmentService.swift
// bitchat
//
// Manages match assignments with race condition prevention.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Service for managing match assignments to scoreboards.
/// Prevents double-assignment and tracks assignment state.
@MainActor
final class MatchAssignmentService: ObservableObject {

    static let shared = MatchAssignmentService()

    // MARK: - Published State

    @Published private(set) var assignments: [UUID: MatchAssignment] = [:]
    @Published private(set) var pendingAssignments: Set<UUID> = []
    @Published private(set) var lastError: AssignmentError?

    // MARK: - Dependencies

    private let tournamentManager = TournamentManager.shared
    private let messageHandler = TournamentMessageHandler.shared
    private let connectionMonitor = DeviceConnectionMonitor.shared

    // MARK: - Configuration

    private let assignmentTimeout: TimeInterval = 10.0

    // MARK: - State

    private var assignmentTimers: [UUID: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Listen for match accepted responses via NotificationCenter
        NotificationCenter.default.publisher(for: .matchAccepted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let matchId = notification.userInfo?["matchId"] as? UUID,
                   let deviceId = notification.userInfo?["deviceId"] as? String {
                    self?.handleMatchAccepted(matchId: matchId, deviceId: deviceId)
                }
            }
            .store(in: &cancellables)

        // Listen for device disconnections
        NotificationCenter.default.publisher(for: .matchInterrupted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let matchId = notification.userInfo?["matchId"] as? UUID {
                    self?.handleAssignmentInterrupted(matchId: matchId)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Assignment API

    /// Assigns a match to a device.
    /// Returns immediately but assignment is confirmed asynchronously.
    func assignMatch(matchId: UUID, to deviceId: String) -> Result<Void, AssignmentError> {
        // Validate the assignment
        if let error = validateAssignment(matchId: matchId, deviceId: deviceId) {
            lastError = error
            return .failure(error)
        }

        // Mark as pending
        pendingAssignments.insert(matchId)

        // Create assignment record
        let assignment = MatchAssignment(
            matchId: matchId,
            deviceId: deviceId,
            status: .pending,
            assignedAt: Date()
        )
        assignments[matchId] = assignment

        // Send assignment message
        guard let tournament = tournamentManager.currentTournament,
              let match = tournament.match(byId: matchId) else {
            pendingAssignments.remove(matchId)
            assignments.removeValue(forKey: matchId)
            let error = AssignmentError.matchNotFound
            lastError = error
            return .failure(error)
        }

        let config = tournament.createMatchConfiguration(for: match)
        messageHandler.assignMatchToDevice(match: match, deviceId: deviceId, config: config)

        // Start timeout timer
        startAssignmentTimeout(matchId: matchId)

        lastError = nil
        return .success(())
    }

    /// Cancels a pending assignment.
    func cancelAssignment(matchId: UUID) {
        pendingAssignments.remove(matchId)
        assignmentTimers[matchId]?.cancel()
        assignmentTimers.removeValue(forKey: matchId)

        if var assignment = assignments[matchId] {
            assignment.status = .cancelled
            assignments[matchId] = assignment
        }

        // Notify connected scoreboards that the match has been unassigned
        messageHandler.broadcastMatchUnassigned(matchId: matchId, reason: "Unassigned by tournament master")

        // Unassign in tournament
        tournamentManager.unassignMatch(matchId: matchId)
    }

    /// Checks if a match can be assigned.
    func canAssign(matchId: UUID) -> Bool {
        validateAssignment(matchId: matchId, deviceId: "") == nil ||
        validateAssignment(matchId: matchId, deviceId: "")?.isDeviceRelated == true
    }

    /// Checks if a device is available for assignment.
    func isDeviceAvailable(deviceId: String) -> Bool {
        // Check if device is connected
        guard let deviceInfo = connectionMonitor.connectedDevices[deviceId],
              deviceInfo.status == .connected else {
            return false
        }

        // Check if device already has an active assignment
        let hasActiveAssignment = assignments.values.contains { assignment in
            assignment.deviceId == deviceId &&
            (assignment.status == .pending || assignment.status == .confirmed)
        }

        return !hasActiveAssignment
    }

    /// Gets devices available for a specific match.
    func getAvailableDevices(for matchId: UUID) -> [DeviceConnectionInfo] {
        connectionMonitor.getAvailableDevices().filter { device in
            isDeviceAvailable(deviceId: device.deviceId)
        }
    }

    // MARK: - Validation

    private func validateAssignment(matchId: UUID, deviceId: String) -> AssignmentError? {
        // Check tournament exists
        guard let tournament = tournamentManager.currentTournament else {
            return .noTournament
        }

        // Check match exists
        guard let match = tournament.match(byId: matchId) else {
            return .matchNotFound
        }

        // Check match is ready (both players known)
        guard match.isReady else {
            return .matchNotReady
        }

        // Check match is not already assigned or complete
        if match.status != .pending {
            if match.status == .complete {
                return .matchComplete
            }
            return .alreadyAssigned
        }

        // Check not already pending
        if pendingAssignments.contains(matchId) {
            return .assignmentPending
        }

        // Check device (only if deviceId provided)
        if !deviceId.isEmpty {
            guard connectionMonitor.connectedDevices[deviceId]?.status == .connected else {
                return .deviceNotConnected
            }

            if !isDeviceAvailable(deviceId: deviceId) {
                return .deviceBusy
            }
        }

        return nil
    }

    // MARK: - Event Handlers

    private func handleMatchAccepted(matchId: UUID, deviceId: String) {
        pendingAssignments.remove(matchId)
        assignmentTimers[matchId]?.cancel()
        assignmentTimers.removeValue(forKey: matchId)

        if var assignment = assignments[matchId] {
            assignment.status = .confirmed
            assignment.confirmedAt = Date()
            assignments[matchId] = assignment
        }

        // Update tournament state
        tournamentManager.startMatch(matchId: matchId)
    }

    private func handleAssignmentInterrupted(matchId: UUID) {
        pendingAssignments.remove(matchId)
        assignmentTimers[matchId]?.cancel()
        assignmentTimers.removeValue(forKey: matchId)

        if var assignment = assignments[matchId] {
            assignment.status = .interrupted
            assignments[matchId] = assignment
        }
    }

    private func startAssignmentTimeout(matchId: UUID) {
        assignmentTimers[matchId]?.cancel()

        assignmentTimers[matchId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(assignmentTimeout * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                // Check if still pending
                if pendingAssignments.contains(matchId) {
                    handleAssignmentTimeout(matchId: matchId)
                }
            }
        }
    }

    private func handleAssignmentTimeout(matchId: UUID) {
        pendingAssignments.remove(matchId)
        assignmentTimers.removeValue(forKey: matchId)

        if var assignment = assignments[matchId] {
            assignment.status = .timeout
            assignments[matchId] = assignment
        }

        // Unassign in tournament
        tournamentManager.unassignMatch(matchId: matchId)

        lastError = .assignmentTimeout
    }

    // MARK: - Cleanup

    /// Clears all assignment state (call when leaving room).
    func clearAll() {
        for timer in assignmentTimers.values {
            timer.cancel()
        }
        assignmentTimers.removeAll()
        pendingAssignments.removeAll()
        assignments.removeAll()
        lastError = nil
    }
}

// MARK: - Supporting Types

struct MatchAssignment {
    let matchId: UUID
    let deviceId: String
    var status: AssignmentStatus
    let assignedAt: Date
    var confirmedAt: Date?
}

enum AssignmentStatus: String {
    case pending
    case confirmed
    case cancelled
    case timeout
    case interrupted
}

enum AssignmentError: Error, LocalizedError {
    case noTournament
    case matchNotFound
    case matchNotReady
    case matchComplete
    case alreadyAssigned
    case assignmentPending
    case deviceNotConnected
    case deviceBusy
    case assignmentTimeout

    var isDeviceRelated: Bool {
        switch self {
        case .deviceNotConnected, .deviceBusy:
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .noTournament:
            return "No active tournament"
        case .matchNotFound:
            return "Match not found"
        case .matchNotReady:
            return "Match players not yet determined"
        case .matchComplete:
            return "Match is already complete"
        case .alreadyAssigned:
            return "Match is already assigned"
        case .assignmentPending:
            return "Assignment already in progress"
        case .deviceNotConnected:
            return "Device is not connected"
        case .deviceBusy:
            return "Device is busy with another match"
        case .assignmentTimeout:
            return "Assignment timed out - device did not respond"
        }
    }
}
