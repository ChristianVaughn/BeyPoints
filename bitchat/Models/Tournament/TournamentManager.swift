//
// TournamentManager.swift
// bitchat
//
// Manages tournament state for the Master device.
// Part of BeyScore Tournament System.
//

import Foundation
import SwiftUI
import Combine

/// Manages the current tournament state for Master mode.
@MainActor
final class TournamentManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TournamentManager()

    // MARK: - Published Properties

    @Published private(set) var currentTournament: Tournament?
    @Published private(set) var connectedScoreboards: [ConnectedScoreboard] = []
    @Published private(set) var pendingSubmissions: [PendingScoreSubmission] = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadSavedTournament()
    }

    // MARK: - Tournament Creation

    /// Creates a new tournament.
    func createTournament(
        name: String,
        roomCode: String,
        players: [String],
        generation: BeybladeGeneration,
        matchType: MatchType,
        bestOf: BestOf,
        ownFinishEnabled: Bool,
        shuffle: Bool = false
    ) {
        let tournament = Tournament.create(
            name: name,
            roomCode: roomCode,
            players: players,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            shuffle: shuffle
        )

        currentTournament = tournament
        saveTournament()
    }

    /// Clears the current tournament.
    func clearTournament() {
        currentTournament = nil
        pendingSubmissions = []
        connectedScoreboards = []
        UserDefaults.standard.removeObject(forKey: tournamentKey)

        // Also leave the room
        TournamentRoomManager.shared.leaveRoom()
    }

    /// Sets the current tournament (used when restoring or receiving from UI).
    func setTournament(_ tournament: Tournament) {
        currentTournament = tournament
        saveTournament()

        // Also join the room as Master so we can receive scoreboard messages
        let roomManager = TournamentRoomManager.shared
        if !roomManager.isInRoom {
            print("[BeyScore] Master setting up room with code: \(tournament.roomCode)")
            roomManager.setupMasterRoom(code: tournament.roomCode)
            print("[BeyScore] Master room setup complete. isInRoom=\(roomManager.isInRoom), deviceMode=\(roomManager.deviceMode)")
        } else {
            print("[BeyScore] Master already in room: \(roomManager.currentRoomCode?.code ?? "nil")")
        }
    }

    // MARK: - Match Assignment

    /// Assigns a match to a scoreboard device.
    func assignMatch(matchId: UUID, to deviceId: String) {
        guard var tournament = currentTournament else { return }

        tournament.assignMatch(matchId: matchId, to: deviceId)
        currentTournament = tournament

        // Update scoreboard status
        if let index = connectedScoreboards.firstIndex(where: { $0.id == deviceId }) {
            connectedScoreboards[index].status = .matchAssigned
            connectedScoreboards[index].currentMatchId = matchId
        }

        saveTournament()
    }

    /// Unassigns a match from a scoreboard.
    func unassignMatch(matchId: UUID) {
        guard var tournament = currentTournament else { return }

        // Find the device and clear its assignment
        if let match = tournament.match(byId: matchId),
           let deviceId = match.assignedDeviceId,
           let index = connectedScoreboards.firstIndex(where: { $0.id == deviceId }) {
            connectedScoreboards[index].status = .idle
            connectedScoreboards[index].currentMatchId = nil
        }

        tournament.unassignMatch(matchId: matchId)
        currentTournament = tournament
        saveTournament()
    }

    /// Marks a match as in-progress (after scoreboard accepts).
    func startMatch(matchId: UUID) {
        guard var tournament = currentTournament,
              let index = tournament.matchIndex(byId: matchId) else { return }

        tournament.matches[index].status = .inProgress
        currentTournament = tournament

        // Update scoreboard status
        if let deviceId = tournament.matches[index].assignedDeviceId,
           let scoreboardIndex = connectedScoreboards.firstIndex(where: { $0.id == deviceId }) {
            connectedScoreboards[scoreboardIndex].status = .scoring
        }

        saveTournament()
    }

    // MARK: - Score Management

    /// Handles a score submission from a scoreboard.
    func receiveScoreSubmission(_ submission: PendingScoreSubmission) {
        guard var tournament = currentTournament else { return }

        // Mark match as awaiting approval
        tournament.submitScore(matchId: submission.matchId)
        currentTournament = tournament

        // Update scoreboard status
        if let index = connectedScoreboards.firstIndex(where: { $0.id == submission.deviceId }) {
            connectedScoreboards[index].status = .awaitingApproval
        }

        // Add to pending submissions
        if !pendingSubmissions.contains(where: { $0.matchId == submission.matchId }) {
            pendingSubmissions.append(submission)
        }

        saveTournament()
    }

    /// Approves a pending score submission.
    func approveScore(matchId: UUID) {
        guard var tournament = currentTournament,
              let submission = pendingSubmissions.first(where: { $0.matchId == matchId }) else {
            return
        }

        // Update tournament with result
        tournament.updateMatchResult(
            matchId: matchId,
            winner: submission.winner,
            player1Score: submission.player1FinalScore,
            player2Score: submission.player2FinalScore,
            player1SetWins: submission.player1SetWins,
            player2SetWins: submission.player2SetWins,
            history: submission.matchHistory
        )
        currentTournament = tournament

        // Update scoreboard status
        if let index = connectedScoreboards.firstIndex(where: { $0.id == submission.deviceId }) {
            connectedScoreboards[index].status = .idle
            connectedScoreboards[index].currentMatchId = nil
        }

        // Remove from pending
        pendingSubmissions.removeAll { $0.matchId == matchId }

        saveTournament()
    }

    /// Rejects a pending score submission.
    func rejectScore(matchId: UUID, reason: String?) {
        guard var tournament = currentTournament,
              let submission = pendingSubmissions.first(where: { $0.matchId == matchId }) else {
            return
        }

        // Reset match to assigned state
        if let index = tournament.matchIndex(byId: matchId) {
            tournament.matches[index].status = .assigned
        }
        currentTournament = tournament

        // Update scoreboard status back to assigned
        if let index = connectedScoreboards.firstIndex(where: { $0.id == submission.deviceId }) {
            connectedScoreboards[index].status = .matchAssigned
        }

        // Remove from pending
        pendingSubmissions.removeAll { $0.matchId == matchId }

        saveTournament()
    }

    // MARK: - Scoreboard Management

    /// Registers a new scoreboard device.
    func registerScoreboard(deviceId: String, deviceName: String) {
        if let index = connectedScoreboards.firstIndex(where: { $0.id == deviceId }) {
            // Update existing
            connectedScoreboards[index].deviceName = deviceName
            connectedScoreboards[index].lastSeen = Date()
        } else {
            // Add new
            let scoreboard = ConnectedScoreboard(
                id: deviceId,
                deviceName: deviceName
            )
            connectedScoreboards.append(scoreboard)
        }

        // Notify observers that a scoreboard has joined
        NotificationCenter.default.post(
            name: .scoreboardJoined,
            object: nil,
            userInfo: [
                "deviceId": deviceId,
                "deviceName": deviceName
            ]
        )
    }

    /// Removes a scoreboard device.
    func removeScoreboard(deviceId: String) {
        // Unassign any matches
        if let tournament = currentTournament {
            for match in tournament.matches {
                if match.assignedDeviceId == deviceId {
                    unassignMatch(matchId: match.id)
                }
            }
        }

        connectedScoreboards.removeAll { $0.id == deviceId }
    }

    /// Updates the last seen time for a scoreboard.
    func updateScoreboardLastSeen(deviceId: String) {
        if let index = connectedScoreboards.firstIndex(where: { $0.id == deviceId }) {
            connectedScoreboards[index].lastSeen = Date()
        }
    }

    // MARK: - Computed Properties

    /// Matches available for assignment (pending, ready, not assigned).
    var assignableMatches: [TournamentMatch] {
        guard let tournament = currentTournament else { return [] }
        return tournament.matches.filter {
            $0.status == .pending && $0.isReady && $0.assignedDeviceId == nil
        }
    }

    /// Scoreboards available for assignment (idle).
    var availableScoreboards: [ConnectedScoreboard] {
        return connectedScoreboards.filter { $0.status == .idle }
    }

    /// Whether there are pending submissions to review.
    var hasPendingSubmissions: Bool {
        return !pendingSubmissions.isEmpty
    }

    // MARK: - Persistence

    private let tournamentKey = "beyscore.currentTournament"

    private func saveTournament() {
        guard let tournament = currentTournament else {
            UserDefaults.standard.removeObject(forKey: tournamentKey)
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(tournament) {
            UserDefaults.standard.set(data, forKey: tournamentKey)
        }
    }

    private func loadSavedTournament() {
        guard let data = UserDefaults.standard.data(forKey: tournamentKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let tournament = try? decoder.decode(Tournament.self, from: data) {
            currentTournament = tournament
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let scoreboardJoined = Notification.Name("beyscore.scoreboardJoined")
    static let matchAccepted = Notification.Name("beyscore.matchAccepted")
}
