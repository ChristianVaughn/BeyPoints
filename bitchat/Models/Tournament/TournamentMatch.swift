//
// TournamentMatch.swift
// bitchat
//
// Individual match within a tournament bracket.
// Part of BeyScore Tournament System.
//

import Foundation

/// A single match within a tournament bracket.
struct TournamentMatch: Codable, Identifiable, Equatable {
    let id: UUID
    let roundNumber: Int
    let matchNumber: Int  // Position within round (0-indexed)

    // Players
    var player1Name: String?
    var player2Name: String?

    // Scores
    var player1Score: Int
    var player2Score: Int
    var player1SetWins: Int
    var player2SetWins: Int

    // State
    var status: MatchStatus
    var assignedDeviceId: String?
    var winner: String?
    var matchHistory: [HistoryEntry]

    // Bracket progression
    var nextMatchId: UUID?
    var nextMatchSlot: Player?  // Which slot in the next match

    // Tournament stage (for multi-stage and group tournaments)
    var stage: TournamentStage

    // Double Elimination specifics
    var bracketType: BracketType
    var isGrandFinal: Bool
    var isGrandFinalReset: Bool

    // Losers bracket: where loser goes after this match
    var loserNextMatchId: UUID?
    var loserNextMatchSlot: Player?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        roundNumber: Int,
        matchNumber: Int,
        player1Name: String? = nil,
        player2Name: String? = nil,
        nextMatchId: UUID? = nil,
        nextMatchSlot: Player? = nil,
        stage: TournamentStage = .main,
        bracketType: BracketType = .winners
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.matchNumber = matchNumber
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = 0
        self.player2Score = 0
        self.player1SetWins = 0
        self.player2SetWins = 0
        self.status = .pending
        self.assignedDeviceId = nil
        self.winner = nil
        self.matchHistory = []
        self.nextMatchId = nextMatchId
        self.nextMatchSlot = nextMatchSlot
        self.stage = stage
        self.bracketType = bracketType
        self.isGrandFinal = false
        self.isGrandFinalReset = false
        self.loserNextMatchId = nil
        self.loserNextMatchSlot = nil
    }

    // MARK: - Computed Properties

    /// Whether the match is ready to be played (both players known).
    var isReady: Bool {
        return player1Name != nil && player2Name != nil
    }

    /// Whether the match is a bye (only one player).
    var isBye: Bool {
        return (player1Name != nil && player2Name == nil) ||
               (player1Name == nil && player2Name != nil)
    }

    /// Display name for the match (e.g., "Round 1 Match 1").
    var displayName: String {
        return "R\(roundNumber) M\(matchNumber + 1)"
    }

    /// Long display name.
    var longDisplayName: String {
        return "Round \(roundNumber) - Match \(matchNumber + 1)"
    }

    /// The loser of the match, if complete.
    var loser: String? {
        guard let winner = winner else { return nil }
        if player1Name == winner {
            return player2Name
        } else {
            return player1Name
        }
    }

    /// Score display string (e.g., "4 - 2").
    var scoreDisplay: String {
        return "\(player1Score) - \(player2Score)"
    }

    /// Set wins display string (e.g., "2 - 1").
    var setWinsDisplay: String {
        return "\(player1SetWins) - \(player2SetWins)"
    }
}

// MARK: - Connected Scoreboard

/// A scoreboard device connected to the tournament room.
struct ConnectedScoreboard: Codable, Identifiable, Equatable {
    let id: String  // Device ID
    var deviceName: String
    var status: ScoreboardStatus
    var currentMatchId: UUID?
    var lastSeen: Date

    init(
        id: String,
        deviceName: String,
        status: ScoreboardStatus = .idle,
        currentMatchId: UUID? = nil,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.deviceName = deviceName
        self.status = status
        self.currentMatchId = currentMatchId
        self.lastSeen = lastSeen
    }
}

/// Status of a connected scoreboard device.
enum ScoreboardStatus: String, Codable {
    case idle = "idle"
    case matchAssigned = "assigned"
    case scoring = "scoring"
    case awaitingApproval = "awaiting"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .matchAssigned: return "Match Assigned"
        case .scoring: return "Scoring"
        case .awaitingApproval: return "Awaiting Approval"
        }
    }
}

// MARK: - Score Submission

/// A pending score submission waiting for master approval.
struct PendingScoreSubmission: Codable, Identifiable, Equatable {
    let id: UUID  // Same as match ID
    let matchId: UUID
    let deviceId: String
    let winner: String
    let player1FinalScore: Int
    let player2FinalScore: Int
    let player1SetWins: Int
    let player2SetWins: Int
    let matchHistory: [HistoryEntry]
    let submittedAt: Date

    init(
        matchId: UUID,
        deviceId: String,
        winner: String,
        player1FinalScore: Int,
        player2FinalScore: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        matchHistory: [HistoryEntry]
    ) {
        self.id = matchId
        self.matchId = matchId
        self.deviceId = deviceId
        self.winner = winner
        self.player1FinalScore = player1FinalScore
        self.player2FinalScore = player2FinalScore
        self.player1SetWins = player1SetWins
        self.player2SetWins = player2SetWins
        self.matchHistory = matchHistory
        self.submittedAt = Date()
    }
}
