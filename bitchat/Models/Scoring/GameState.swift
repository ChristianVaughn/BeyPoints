//
// GameState.swift
// bitchat
//
// Tracks the current state of a Beyblade match.
// Part of BeyScore Tournament System.
//

import Foundation

/// Complete state of a Beyblade match including scores, history, and configuration.
struct GameState: Codable, Equatable {

    // MARK: - Configuration

    var generation: BeybladeGeneration
    var matchType: MatchType
    var bestOf: BestOf
    var ownFinishEnabled: Bool

    var player1Name: String
    var player2Name: String

    // MARK: - Current Game State

    var player1Score: Int
    var player2Score: Int

    var player1ShowWarning: Bool
    var player2ShowWarning: Bool

    // MARK: - Set/Series State (for Best-of)

    var player1SetWins: Int
    var player2SetWins: Int
    var currentGameNumber: Int

    // MARK: - History

    var matchHistory: [HistoryEntry]

    // MARK: - Initialization

    init(
        generation: BeybladeGeneration = .x,
        matchType: MatchType = .points4,
        bestOf: BestOf = .none,
        ownFinishEnabled: Bool = false,
        player1Name: String = "Player 1",
        player2Name: String = "Player 2"
    ) {
        self.generation = generation
        self.matchType = matchType
        self.bestOf = bestOf
        self.ownFinishEnabled = ownFinishEnabled && generation.supportsOwnFinish
        self.player1Name = player1Name
        self.player2Name = player2Name

        self.player1Score = 0
        self.player2Score = 0
        self.player1ShowWarning = false
        self.player2ShowWarning = false
        self.player1SetWins = 0
        self.player2SetWins = 0
        self.currentGameNumber = 1
        self.matchHistory = []
    }

    // MARK: - Computed Properties

    /// Target points to win the current game.
    var maxPoints: Int? {
        return matchType.maxPoints
    }

    /// Whether the current game has ended.
    var gameEnded: Bool {
        guard let max = maxPoints else {
            return false  // No limit mode never ends automatically
        }
        return (player1Score >= max || player2Score >= max) && player1Score != player2Score
    }

    /// The winner of the current game, if ended.
    var gameWinner: Player? {
        guard gameEnded else { return nil }
        return player1Score > player2Score ? .player1 : .player2
    }

    /// Whether the entire match (all sets) has ended.
    var matchEnded: Bool {
        guard let winsRequired = bestOf.winsRequired else {
            // Single game mode - match ends when game ends
            return gameEnded
        }
        return player1SetWins >= winsRequired || player2SetWins >= winsRequired
    }

    /// The winner of the entire match, if ended.
    var matchWinner: Player? {
        guard matchEnded else { return nil }
        if let winsRequired = bestOf.winsRequired {
            if player1SetWins >= winsRequired { return .player1 }
            if player2SetWins >= winsRequired { return .player2 }
            return nil
        } else {
            return gameWinner
        }
    }

    /// The winner's name.
    var winnerName: String? {
        guard let winner = matchWinner else { return nil }
        return winner == .player1 ? player1Name : player2Name
    }

    /// Whether the game has started (any scoring action taken).
    var gameHasStarted: Bool {
        return !matchHistory.isEmpty || player1Score > 0 || player2Score > 0
    }

    /// Current set text for display.
    var currentSetText: String {
        guard bestOf != .none else { return "" }
        return "Set \(currentGameNumber)"
    }

    /// Score for a specific player.
    func score(for player: Player) -> Int {
        return player == .player1 ? player1Score : player2Score
    }

    /// Set wins for a specific player.
    func setWins(for player: Player) -> Int {
        return player == .player1 ? player1SetWins : player2SetWins
    }

    /// Name for a specific player.
    func name(for player: Player) -> String {
        return player == .player1 ? player1Name : player2Name
    }

    /// Whether warning is shown for a player.
    func showWarning(for player: Player) -> Bool {
        return player == .player1 ? player1ShowWarning : player2ShowWarning
    }

    // MARK: - Available Conditions

    /// Win conditions available for the current generation.
    var availableConditions: [WinCondition] {
        return generation.availableConditions
    }

    /// Whether own finish is available.
    var canUseOwnFinish: Bool {
        return ownFinishEnabled && generation.supportsOwnFinish
    }
}

// MARK: - Match Configuration

/// Configuration for setting up a new match.
struct MatchConfiguration: Codable, Equatable {
    var generation: BeybladeGeneration
    var matchType: MatchType
    var bestOf: BestOf
    var ownFinishEnabled: Bool
    var player1Name: String
    var player2Name: String

    init(
        generation: BeybladeGeneration = .x,
        matchType: MatchType? = nil,
        bestOf: BestOf = .none,
        ownFinishEnabled: Bool = false,
        player1Name: String = "Player 1",
        player2Name: String = "Player 2"
    ) {
        self.generation = generation
        self.matchType = matchType ?? generation.defaultMatchType
        self.bestOf = bestOf
        self.ownFinishEnabled = ownFinishEnabled && generation.supportsOwnFinish
        self.player1Name = player1Name
        self.player2Name = player2Name
    }

    /// Creates a new GameState from this configuration.
    func createGameState() -> GameState {
        return GameState(
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            player1Name: player1Name,
            player2Name: player2Name
        )
    }
}
