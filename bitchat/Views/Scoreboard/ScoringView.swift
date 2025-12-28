//
// ScoringView.swift
// bitchat
//
// Main scoring screen for an active Beyblade match.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Main view for scoring an active match.
struct ScoringView: View {
    @StateObject var scoringManager: ScoringManager
    @State private var showHistory = false
    @State private var showResults = false
    @State private var showSetup = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onMatchComplete: ((GameState) -> Void)?
    var onCancel: (() -> Void)?
    var onSubmitScore: ((GameState) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()

                // Main content
                if isLandscape {
                    landscapeLayout(size: geometry.size)
                } else {
                    portraitLayout(size: geometry.size)
                }

                // Results overlay
                if showResults {
                    GameResultsOverlay(
                        gameState: scoringManager.gameState,
                        onDismiss: { showResults = false },
                        onNewGame: handleNewGame,
                        onNextGame: handleNextGame,
                        onViewHistory: { showHistory = true },
                        onSubmitScore: onSubmitScore != nil ? {
                            onSubmitScore?(scoringManager.gameState)
                        } : nil
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showResults)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Undo/Redo
                    Button(action: { scoringManager.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!scoringManager.canUndo || showResults)

                    Button(action: { scoringManager.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!scoringManager.canRedo || showResults)

                    // History
                    Button(action: { showHistory = true }) {
                        Image(systemName: "list.bullet")
                    }
                    .disabled(showResults)
                }
                .opacity(showResults ? 0.5 : 1.0)
            }
        }
        .sheet(isPresented: $showHistory) {
            MatchHistorySheet(history: scoringManager.gameState.matchHistory)
        }
        .onChange(of: scoringManager.gameState.gameEnded) { ended in
            if ended {
                // Delay slightly for score animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showResults = true
                }
            }
        }
        .onChange(of: scoringManager.gameState.matchEnded) { ended in
            if ended {
                showResults = true
            }
        }
        .onAppear {
            // Enable landscape orientation for scoring view
            OrientationManager.allowAllOrientations()
        }
        .onDisappear {
            // Lock back to portrait when leaving scoring view
            OrientationManager.lockToPortrait()
        }
    }

    // MARK: - Layouts

    private func portraitLayout(size: CGSize) -> some View {
        let cardHeight = (size.height - 60) / 2  // 60 = padding (20*2) + gap (20)

        return VStack(spacing: 20) {
            // Player 1 card
            ScoreCard(
                player: .player1,
                playerName: scoringManager.gameState.player1Name,
                score: scoringManager.gameState.player1Score,
                setWins: scoringManager.gameState.player1SetWins,
                showWarning: scoringManager.gameState.player1ShowWarning,
                generation: scoringManager.gameState.generation,
                bestOf: scoringManager.gameState.bestOf,
                canUseOwnFinish: scoringManager.gameState.canUseOwnFinish,
                isDisabled: scoringManager.isScoreInputDisabled,
                onChipTap: { condition in
                    scoringManager.awardPoints(condition: condition, to: .player1)
                },
                onErrorTap: {
                    scoringManager.handleErrorTap(for: .player1)
                },
                onOwnFinishTap: {
                    scoringManager.applyOwnFinish(to: .player1)
                }
            )
            .frame(height: cardHeight)

            // Player 2 card
            ScoreCard(
                player: .player2,
                playerName: scoringManager.gameState.player2Name,
                score: scoringManager.gameState.player2Score,
                setWins: scoringManager.gameState.player2SetWins,
                showWarning: scoringManager.gameState.player2ShowWarning,
                generation: scoringManager.gameState.generation,
                bestOf: scoringManager.gameState.bestOf,
                canUseOwnFinish: scoringManager.gameState.canUseOwnFinish,
                isDisabled: scoringManager.isScoreInputDisabled,
                onChipTap: { condition in
                    scoringManager.awardPoints(condition: condition, to: .player2)
                },
                onErrorTap: {
                    scoringManager.handleErrorTap(for: .player2)
                },
                onOwnFinishTap: {
                    scoringManager.applyOwnFinish(to: .player2)
                }
            )
            .frame(height: cardHeight)
        }
        .padding(20)
    }

    private func landscapeLayout(size: CGSize) -> some View {
        let cardHeight = size.height - 24  // Full height minus padding (12 * 2)

        return HStack(spacing: 12) {
            // Player 1 card
            CompactScoreCard(
                player: .player1,
                playerName: scoringManager.gameState.player1Name,
                score: scoringManager.gameState.player1Score,
                setWins: scoringManager.gameState.player1SetWins,
                showWarning: scoringManager.gameState.player1ShowWarning,
                generation: scoringManager.gameState.generation,
                bestOf: scoringManager.gameState.bestOf,
                canUseOwnFinish: scoringManager.gameState.canUseOwnFinish,
                isDisabled: scoringManager.isScoreInputDisabled,
                onChipTap: { condition in
                    scoringManager.awardPoints(condition: condition, to: .player1)
                },
                onErrorTap: {
                    scoringManager.handleErrorTap(for: .player1)
                },
                onOwnFinishTap: {
                    scoringManager.applyOwnFinish(to: .player1)
                }
            )
            .frame(height: cardHeight)
            .frame(maxWidth: .infinity)

            // Player 2 card
            CompactScoreCard(
                player: .player2,
                playerName: scoringManager.gameState.player2Name,
                score: scoringManager.gameState.player2Score,
                setWins: scoringManager.gameState.player2SetWins,
                showWarning: scoringManager.gameState.player2ShowWarning,
                generation: scoringManager.gameState.generation,
                bestOf: scoringManager.gameState.bestOf,
                canUseOwnFinish: scoringManager.gameState.canUseOwnFinish,
                isDisabled: scoringManager.isScoreInputDisabled,
                onChipTap: { condition in
                    scoringManager.awardPoints(condition: condition, to: .player2)
                },
                onErrorTap: {
                    scoringManager.handleErrorTap(for: .player2)
                },
                onOwnFinishTap: {
                    scoringManager.applyOwnFinish(to: .player2)
                }
            )
            .frame(height: cardHeight)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    // MARK: - Actions

    private func handleNewGame() {
        showResults = false
        scoringManager.resetMatch()
    }

    private func handleNextGame() {
        showResults = false
        scoringManager.advanceToNextGame()
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ScoringView(
            scoringManager: ScoringManager.preview
        )
    }
}
