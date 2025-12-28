//
// GameResultsOverlay.swift
// bitchat
//
// Overlay displayed when a game or match ends.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Overlay displayed when a game ends showing results.
struct GameResultsOverlay: View {
    let gameState: GameState

    var onDismiss: () -> Void
    var onNewGame: () -> Void
    var onNextGame: (() -> Void)?
    var onViewHistory: () -> Void
    var onSubmitScore: (() -> Void)?

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    if !gameState.matchEnded {
                        onDismiss()
                    }
                }

            // Results card
            VStack(spacing: 24) {
                // Winner announcement
                VStack(spacing: 8) {
                    if gameState.matchEnded {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)

                        Text("Match Winner!")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("Set \(gameState.currentGameNumber) Complete")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    if let winner = gameState.matchWinner {
                        Text(gameState.name(for: winner))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }

                // Score summary
                VStack(spacing: 12) {
                    // Final score - show set wins for best-of match end, otherwise points
                    HStack(spacing: 24) {
                        VStack {
                            Text(gameState.player1Name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if gameState.bestOf != .none && gameState.matchEnded {
                                Text("\(gameState.player1SetWins)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            } else {
                                Text("\(gameState.player1Score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                        }

                        Text("-")
                            .font(.title)
                            .foregroundColor(.secondary)

                        VStack {
                            Text(gameState.player2Name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if gameState.bestOf != .none && gameState.matchEnded {
                                Text("\(gameState.player2SetWins)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                            } else {
                                Text("\(gameState.player2Score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // Set wins - only show for set-complete (not match end)
                    if gameState.bestOf != .none && !gameState.matchEnded {
                        HStack(spacing: 24) {
                            VStack {
                                Text("Sets")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(gameState.player1SetWins)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }

                            Text("-")
                                .foregroundColor(.secondary)

                            VStack {
                                Text("Sets")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(gameState.player2SetWins)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)

                // Statistics
                GameStatistics(history: gameState.matchHistory, generation: gameState.generation)

                // Action buttons
                VStack(spacing: 12) {
                    if gameState.matchEnded {
                        // Match is over
                        if let onSubmit = onSubmitScore {
                            Button(action: onSubmit) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("Submit Score")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }

                        Button(action: onNewGame) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("New Match")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else if gameState.bestOf != .none {
                        // Game over but match continues
                        Button(action: { onNextGame?() }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Next Game")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    // View history button
                    Button(action: onViewHistory) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("View History")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }

                    // Close button (if not match end)
                    if !gameState.matchEnded {
                        Button(action: onDismiss) {
                            Text("Close")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(32)
        }
    }
}

// MARK: - Game Statistics

/// Shows win condition breakdown statistics.
struct GameStatistics: View {
    let history: [HistoryEntry]
    let generation: BeybladeGeneration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(generation.availableConditions, id: \.self) { condition in
                    let count = countCondition(condition)
                    if count > 0 {
                        VStack(spacing: 4) {
                            Text(condition.chipLabel)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(condition.chipColor)

                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(minWidth: 40)
                    }
                }

                let penaltyCount = countCondition(.penalty)
                if penaltyCount > 0 {
                    VStack(spacing: 4) {
                        Text("PEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)

                        Text("\(penaltyCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 40)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }

    private func countCondition(_ condition: WinCondition) -> Int {
        history.filter { !$0.isWarning && !$0.isGameDivider && $0.condition == condition }.count
    }
}

// MARK: - Preview

#Preview {
    GameResultsOverlay(
        gameState: {
            var state = GameState(
                generation: .x,
                matchType: .points4,
                bestOf: .bestOf3,
                player1Name: "Alice",
                player2Name: "Bob"
            )
            state.player1Score = 4
            state.player2Score = 2
            state.player1SetWins = 1
            return state
        }(),
        onDismiss: {},
        onNewGame: {},
        onNextGame: {},
        onViewHistory: {}
    )
}
