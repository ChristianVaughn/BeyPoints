//
// ScoringManager.swift
// bitchat
//
// Observable manager for game state with undo/redo support.
// Part of BeyScore Tournament System.
//

import Foundation
import SwiftUI
import Combine

/// Manages the scoring state for a single match with undo/redo support.
@MainActor
final class ScoringManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var gameState: GameState
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // MARK: - Undo/Redo History

    private var historyStack: [HistorySnapshot] = []
    private var historyIndex: Int = -1
    private let maxHistorySize = 100

    // MARK: - Initialization

    init(configuration: MatchConfiguration) {
        self.gameState = configuration.createGameState()
        saveSnapshot()
    }

    init(gameState: GameState) {
        self.gameState = gameState
        saveSnapshot()
    }

    // MARK: - Scoring Actions

    /// Awards points for a win condition.
    func awardPoints(condition: WinCondition, to player: Player) {
        guard ScoringLogic.isValidCondition(condition, for: player, in: gameState) else {
            return
        }

        saveSnapshotBeforeAction()
        gameState = ScoringLogic.applyScore(condition: condition, for: player, to: gameState)
    }

    /// Applies a warning to a player (first offense).
    func applyWarning(to player: Player) {
        guard !gameState.gameEnded else { return }
        guard !gameState.showWarning(for: player) else { return }

        saveSnapshotBeforeAction()
        gameState = ScoringLogic.applyWarning(for: player, to: gameState)
    }

    /// Applies a penalty to a player (after warning).
    func applyPenalty(to player: Player) {
        guard !gameState.gameEnded else { return }
        guard gameState.showWarning(for: player) else { return }

        saveSnapshotBeforeAction()
        gameState = ScoringLogic.applyPenalty(for: player, to: gameState)
    }

    /// Applies own finish (X generation only).
    func applyOwnFinish(to player: Player) {
        guard gameState.canUseOwnFinish else { return }
        guard !gameState.gameEnded else { return }

        saveSnapshotBeforeAction()
        gameState = ScoringLogic.applyScore(condition: .ownFinish, for: player, to: gameState)
    }

    /// Handles the error button tap - either shows warning or applies penalty.
    func handleErrorTap(for player: Player) {
        if gameState.showWarning(for: player) {
            applyPenalty(to: player)
        } else {
            applyWarning(to: player)
        }
    }

    // MARK: - Game Progression

    /// Advances to the next game in a best-of series.
    func advanceToNextGame() {
        guard gameState.gameEnded && !gameState.matchEnded else { return }
        guard gameState.bestOf != .none else { return }

        saveSnapshotBeforeAction()
        gameState = ScoringLogic.advanceToNextGame(gameState)
    }

    /// Resets the entire match.
    func resetMatch() {
        saveSnapshotBeforeAction()
        gameState = ScoringLogic.resetMatch(gameState)
        // Clear undo history for fresh match
        historyStack = []
        historyIndex = -1
        saveSnapshot()
    }

    /// Resets just the current game (preserves set wins).
    func resetCurrentGame() {
        saveSnapshotBeforeAction()
        gameState = ScoringLogic.resetCurrentGame(gameState)
    }

    // MARK: - Configuration Changes

    /// Updates the match configuration (only when game hasn't started).
    func updateConfiguration(_ config: MatchConfiguration) {
        guard !gameState.gameHasStarted else { return }

        gameState = config.createGameState()
        historyStack = []
        historyIndex = -1
        saveSnapshot()
    }

    /// Updates player names.
    func updatePlayerNames(player1: String, player2: String) {
        gameState.player1Name = player1
        gameState.player2Name = player2
    }

    // MARK: - Undo/Redo

    /// Undoes the last action.
    func undo() {
        guard canUndo else { return }

        historyIndex -= 1
        restoreSnapshot()
        updateUndoRedoState()
    }

    /// Redoes the last undone action.
    func redo() {
        guard canRedo else { return }

        historyIndex += 1
        restoreSnapshot()
        updateUndoRedoState()
    }

    // MARK: - Private Snapshot Management

    private func saveSnapshotBeforeAction() {
        // Remove any redo history
        if historyIndex < historyStack.count - 1 {
            historyStack = Array(historyStack.prefix(historyIndex + 1))
        }

        saveSnapshot()
    }

    private func saveSnapshot() {
        let snapshot = HistorySnapshot(from: gameState)
        historyStack.append(snapshot)

        // Limit history size
        if historyStack.count > maxHistorySize {
            historyStack.removeFirst()
        } else {
            historyIndex = historyStack.count - 1
        }

        updateUndoRedoState()
    }

    private func restoreSnapshot() {
        guard historyIndex >= 0 && historyIndex < historyStack.count else { return }

        var newState = gameState
        historyStack[historyIndex].apply(to: &newState)
        gameState = newState
    }

    private func updateUndoRedoState() {
        canUndo = historyIndex > 0
        canRedo = historyIndex < historyStack.count - 1
    }

    // MARK: - Computed Properties for UI

    /// Whether any action buttons should be disabled.
    var isScoreInputDisabled: Bool {
        return gameState.gameEnded
    }

    /// Whether the match is completely finished.
    var isMatchOver: Bool {
        return gameState.matchEnded
    }

    /// The winner's name if match is over.
    var matchWinnerName: String? {
        return gameState.winnerName
    }

    /// Summary text for the current state.
    var summaryText: String {
        if gameState.matchEnded {
            if let winner = gameState.winnerName {
                return "\(winner) wins!"
            }
            return "Match Complete"
        }

        if gameState.gameEnded {
            if gameState.bestOf != .none {
                return "Set \(gameState.currentGameNumber) Complete - Tap to continue"
            }
            return "Set Complete"
        }

        if gameState.bestOf != .none {
            return gameState.currentSetText
        }

        return "Match in progress"
    }
}

// MARK: - Preview Support

extension ScoringManager {
    /// Creates a sample manager for previews.
    static var preview: ScoringManager {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points4,
            bestOf: .bestOf3,
            player1Name: "Player A",
            player2Name: "Player B"
        )
        let manager = ScoringManager(configuration: config)

        // Add some sample actions
        manager.awardPoints(condition: .xtreme, to: .player1)
        manager.awardPoints(condition: .burst, to: .player2)

        return manager
    }
}
