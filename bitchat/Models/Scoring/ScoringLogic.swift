//
// ScoringLogic.swift
// bitchat
//
// Core scoring logic for Beyblade matches.
// Part of BeyScore Tournament System.
//

import Foundation

/// Namespace for scoring logic functions.
enum ScoringLogic {

    // MARK: - Score Application

    /// Applies a win condition to the game state, returning the updated state.
    /// - Parameters:
    ///   - condition: The win condition that occurred
    ///   - player: The player who triggered the condition
    ///   - state: The current game state
    /// - Returns: Updated game state with the score applied
    static func applyScore(
        condition: WinCondition,
        for player: Player,
        to state: GameState
    ) -> GameState {
        var newState = state

        // Can't score if game already ended
        guard !state.gameEnded else { return state }

        // Calculate points
        let points = condition.points(for: state.generation)

        // Determine who gets the points
        let scoringPlayer = condition.awardsToOpponent ? player.opponent : player

        // Apply points
        if scoringPlayer == .player1 {
            newState.player1Score += points
        } else {
            newState.player2Score += points
        }

        // Cap scores at maxPoints to prevent overflow (e.g., 8 in first-to-7)
        if let maxPoints = newState.maxPoints {
            newState.player1Score = min(newState.player1Score, maxPoints)
            newState.player2Score = min(newState.player2Score, maxPoints)
        }

        // Clear warnings:
        // - For regular scoring (XTR, BST, OVR, SPF), clear BOTH players' warnings
        // - For penalty/ownFinish (self-inflicted), only clear the triggering player's warning
        if condition.awardsToOpponent {
            // Penalty or Own Finish - only clear the triggering player's warning
            if player == .player1 {
                newState.player1ShowWarning = false
            } else {
                newState.player2ShowWarning = false
            }
        } else {
            // Regular point scored - clear BOTH warnings
            newState.player1ShowWarning = false
            newState.player2ShowWarning = false
        }

        // Record in history
        let entry = HistoryEntry(
            player: player,
            condition: condition,
            score1After: newState.player1Score,
            score2After: newState.player2Score,
            set1WinsAfter: newState.player1SetWins,
            set2WinsAfter: newState.player2SetWins,
            isPenalty: condition == .penalty || condition == .ownFinish,
            gameNumber: newState.currentGameNumber
        )
        newState.matchHistory.append(entry)

        return newState
    }

    /// Applies a warning to a player.
    /// - Parameters:
    ///   - player: The player receiving the warning
    ///   - state: The current game state
    /// - Returns: Updated game state with warning applied
    static func applyWarning(for player: Player, to state: GameState) -> GameState {
        var newState = state

        if player == .player1 {
            newState.player1ShowWarning = true
        } else {
            newState.player2ShowWarning = true
        }

        // Record warning in history
        let entry = HistoryEntry(
            player: player,
            condition: .penalty,  // Warning precedes penalty
            score1After: newState.player1Score,
            score2After: newState.player2Score,
            set1WinsAfter: newState.player1SetWins,
            set2WinsAfter: newState.player2SetWins,
            isWarning: true,
            gameNumber: newState.currentGameNumber
        )
        newState.matchHistory.append(entry)

        return newState
    }

    /// Applies a penalty (after warning) to a player.
    /// - Parameters:
    ///   - player: The player receiving the penalty
    ///   - state: The current game state
    /// - Returns: Updated game state with penalty applied
    static func applyPenalty(for player: Player, to state: GameState) -> GameState {
        return applyScore(condition: .penalty, for: player, to: state)
    }

    // MARK: - Game/Set Progression

    /// Advances to the next game in a best-of series.
    /// - Parameter state: The current game state
    /// - Returns: Updated game state ready for next game
    static func advanceToNextGame(_ state: GameState) -> GameState {
        guard state.gameEnded && !state.matchEnded else { return state }
        guard state.bestOf != .none else { return state }

        var newState = state

        // Record the game winner's set win
        if let winner = state.gameWinner {
            if winner == .player1 {
                newState.player1SetWins += 1
            } else {
                newState.player2SetWins += 1
            }
        }

        // Add game divider to history
        let divider = HistoryEntry.gameDivider(
            score1After: newState.player1Score,
            score2After: newState.player2Score,
            set1WinsAfter: newState.player1SetWins,
            set2WinsAfter: newState.player2SetWins,
            gameNumber: newState.currentGameNumber
        )
        newState.matchHistory.append(divider)

        // Reset scores for new game
        newState.player1Score = 0
        newState.player2Score = 0
        newState.player1ShowWarning = false
        newState.player2ShowWarning = false
        newState.currentGameNumber += 1

        return newState
    }

    // MARK: - State Reset

    /// Resets the game state for a new match.
    /// - Parameter state: The current game state
    /// - Returns: Fresh game state with same configuration
    static func resetMatch(_ state: GameState) -> GameState {
        return GameState(
            generation: state.generation,
            matchType: state.matchType,
            bestOf: state.bestOf,
            ownFinishEnabled: state.ownFinishEnabled,
            player1Name: state.player1Name,
            player2Name: state.player2Name
        )
    }

    /// Resets just the current game (not set wins).
    /// - Parameter state: The current game state
    /// - Returns: Game state with scores reset but set wins preserved
    static func resetCurrentGame(_ state: GameState) -> GameState {
        var newState = state
        newState.player1Score = 0
        newState.player2Score = 0
        newState.player1ShowWarning = false
        newState.player2ShowWarning = false
        // Don't clear history or set wins
        return newState
    }

    // MARK: - Validation

    /// Checks if a win condition is valid for the current game state.
    /// - Parameters:
    ///   - condition: The win condition to validate
    ///   - player: The player attempting to use it
    ///   - state: The current game state
    /// - Returns: true if the condition can be applied
    static func isValidCondition(
        _ condition: WinCondition,
        for player: Player,
        in state: GameState
    ) -> Bool {
        // Can't score if game ended
        if state.gameEnded { return false }

        // Check if condition is available for this generation
        if !state.generation.availableConditions.contains(condition) {
            // Special handling for penalty and own finish
            if condition == .penalty { return true }
            if condition == .ownFinish {
                return state.canUseOwnFinish
            }
            return false
        }

        return true
    }
}

// MARK: - History Snapshot for Undo/Redo

/// A snapshot of game state for undo/redo functionality.
struct HistorySnapshot: Codable, Equatable {
    let player1Score: Int
    let player2Score: Int
    let player1SetWins: Int
    let player2SetWins: Int
    let player1ShowWarning: Bool
    let player2ShowWarning: Bool
    let currentGameNumber: Int
    let matchHistory: [HistoryEntry]

    init(from state: GameState) {
        self.player1Score = state.player1Score
        self.player2Score = state.player2Score
        self.player1SetWins = state.player1SetWins
        self.player2SetWins = state.player2SetWins
        self.player1ShowWarning = state.player1ShowWarning
        self.player2ShowWarning = state.player2ShowWarning
        self.currentGameNumber = state.currentGameNumber
        self.matchHistory = state.matchHistory
    }

    /// Applies this snapshot to a game state.
    func apply(to state: inout GameState) {
        state.player1Score = player1Score
        state.player2Score = player2Score
        state.player1SetWins = player1SetWins
        state.player2SetWins = player2SetWins
        state.player1ShowWarning = player1ShowWarning
        state.player2ShowWarning = player2ShowWarning
        state.currentGameNumber = currentGameNumber
        state.matchHistory = matchHistory
    }
}
