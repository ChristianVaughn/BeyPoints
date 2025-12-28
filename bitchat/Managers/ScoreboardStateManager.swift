//
// ScoreboardStateManager.swift
// bitchat
//
// Manages scoreboard match state for reconnection recovery.
// Part of BeyScore Tournament System.
//

import Foundation

/// Manages the current scoreboard match state.
/// Used for state preservation during reconnection.
@MainActor
final class ScoreboardStateManager: ObservableObject {

    static let shared = ScoreboardStateManager()

    // MARK: - Published State

    @Published var isInMatch = false
    @Published var currentGameState: GameState?
    @Published var currentMatchId: UUID?

    // MARK: - Initialization

    private init() {}

    // MARK: - State Management

    /// Sets the current match state.
    func setMatchState(matchId: UUID, gameState: GameState) {
        currentMatchId = matchId
        currentGameState = gameState
        isInMatch = true
    }

    /// Restores a game state (e.g., after reconnection).
    func restoreGameState(_ state: GameState) {
        currentGameState = state
        isInMatch = true
    }

    /// Clears all match state.
    func clearState() {
        isInMatch = false
        currentGameState = nil
        currentMatchId = nil
    }
}
