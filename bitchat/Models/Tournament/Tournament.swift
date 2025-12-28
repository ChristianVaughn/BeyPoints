//
// Tournament.swift
// bitchat
//
// Tournament data model for single-elimination brackets.
// Part of BeyScore Tournament System.
//

import Foundation

/// The status of a tournament.
enum TournamentStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case complete = "complete"

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .complete: return "Complete"
        }
    }
}

/// A single-elimination tournament.
struct Tournament: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let roomCode: String
    var generation: BeybladeGeneration
    var matchType: MatchType
    var bestOf: BestOf
    var ownFinishEnabled: Bool
    var players: [String]
    var matches: [TournamentMatch]
    var status: TournamentStatus
    let createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        roomCode: String,
        generation: BeybladeGeneration = .x,
        matchType: MatchType = .points4,
        bestOf: BestOf = .none,
        ownFinishEnabled: Bool = false,
        players: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.roomCode = roomCode
        self.generation = generation
        self.matchType = matchType
        self.bestOf = bestOf
        self.ownFinishEnabled = ownFinishEnabled && generation.supportsOwnFinish
        self.players = players
        self.matches = []
        self.status = .notStarted
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// Number of rounds in the tournament.
    var numberOfRounds: Int {
        guard players.count > 1 else { return 0 }
        return Int(ceil(log2(Double(players.count))))
    }

    /// Total number of matches.
    var totalMatches: Int {
        return matches.count
    }

    /// Number of completed matches.
    var completedMatches: Int {
        return matches.filter { $0.status == .complete }.count
    }

    /// Number of pending matches.
    var pendingMatches: Int {
        return matches.filter { $0.status == .pending }.count
    }

    /// The current round being played.
    var currentRound: Int {
        for round in 1...numberOfRounds {
            let roundMatches = matches.filter { $0.roundNumber == round }
            if roundMatches.contains(where: { $0.status != .complete }) {
                return round
            }
        }
        return numberOfRounds
    }

    /// The tournament winner, if complete.
    var winner: String? {
        guard status == .complete else { return nil }
        return matches.first(where: { $0.roundNumber == numberOfRounds })?.winner
    }

    /// Matches in a specific round.
    func matches(inRound round: Int) -> [TournamentMatch] {
        return matches.filter { $0.roundNumber == round }.sorted { $0.matchNumber < $1.matchNumber }
    }

    /// Gets a match by ID.
    func match(byId id: UUID) -> TournamentMatch? {
        return matches.first { $0.id == id }
    }

    /// Gets the index of a match by ID.
    func matchIndex(byId id: UUID) -> Int? {
        return matches.firstIndex { $0.id == id }
    }

    // MARK: - Match Configuration

    /// Creates a MatchConfiguration for scoring.
    func createMatchConfiguration(for match: TournamentMatch) -> MatchConfiguration {
        MatchConfiguration(
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            player1Name: match.player1Name ?? "TBD",
            player2Name: match.player2Name ?? "TBD"
        )
    }
}

// MARK: - Tournament Extension for Bracket Updates

extension Tournament {

    /// Updates a match result and advances winner if applicable.
    mutating func updateMatchResult(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        history: [HistoryEntry]
    ) {
        guard let index = matchIndex(byId: matchId) else { return }

        var match = matches[index]
        match.player1Score = player1Score
        match.player2Score = player2Score
        match.player1SetWins = player1SetWins
        match.player2SetWins = player2SetWins
        match.winner = winner
        match.status = .complete
        match.matchHistory = history

        matches[index] = match

        // Advance winner to next match
        if let nextId = match.nextMatchId,
           let nextIndex = matchIndex(byId: nextId) {
            var nextMatch = matches[nextIndex]
            if match.nextMatchSlot == .player1 {
                nextMatch.player1Name = winner
            } else {
                nextMatch.player2Name = winner
            }
            matches[nextIndex] = nextMatch
        }

        // Check if tournament is complete
        if matches.allSatisfy({ $0.status == .complete }) {
            status = .complete
        } else if status == .notStarted {
            status = .inProgress
        }
    }

    /// Assigns a match to a device.
    mutating func assignMatch(matchId: UUID, to deviceId: String) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].assignedDeviceId = deviceId
        matches[index].status = .assigned

        if status == .notStarted {
            status = .inProgress
        }
    }

    /// Marks a match as in progress.
    mutating func startMatch(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].status = .inProgress
    }

    /// Marks a match as awaiting approval.
    mutating func submitScore(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].status = .awaitingApproval
    }

    /// Unassigns a match from a device.
    mutating func unassignMatch(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].assignedDeviceId = nil
        matches[index].status = .pending
    }
}
