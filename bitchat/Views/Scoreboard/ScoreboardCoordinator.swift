//
// ScoreboardCoordinator.swift
// bitchat
//
// Coordinates the scoreboard flow between setup, scoring, and submission.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Coordinates the scoreboard flow.
struct ScoreboardCoordinator: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var roomManager = TournamentRoomManager.shared
    @StateObject private var messageHandler = TournamentMessageHandler.shared
    @State private var currentScreen: ScoreboardScreen = .idle
    @State private var scoringManager: ScoringManager?
    @State private var showSetup = false
    @State private var showRoomEntry = false
    @State private var assignedMatch: AssignMatchMessage?
    @State private var currentMatchId: UUID?
    @State private var showRejectionAlert = false
    @State private var rejectionReason: String?
    @State private var showRoomClosedAlert = false
    @State private var roomClosedReason: String?
    @State private var showMatchUnassignedAlert = false
    @State private var matchUnassignedReason: String?

    enum ScoreboardScreen {
        case idle           // Waiting for match assignment or manual start
        case scoring        // Active scoring
        case awaitingApproval // Score submitted, waiting for master
    }

    var body: some View {
        NavigationView {
            Group {
                switch currentScreen {
                case .idle:
                    idleView

                case .scoring:
                    if let manager = scoringManager {
                        ScoringView(
                            scoringManager: manager,
                            onMatchComplete: handleMatchComplete,
                            onCancel: handleCancel,
                            onSubmitScore: roomManager.isInRoom && currentMatchId != nil ? { state in
                                handleMatchComplete(state)
                            } : nil
                        )
                    }

                case .awaitingApproval:
                    awaitingApprovalView
                }
            }
            .navigationTitle("Scoreboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                // Only show menu when in a room (to allow leaving)
                if roomManager.isInRoom {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive, action: { roomManager.leaveRoom() }) {
                                Label("Leave Room", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSetup) {
            GameSetupView { config in
                startMatch(with: config)
            }
        }
        .sheet(isPresented: $showRoomEntry) {
            RoomCodeEntryView()
        }
        .alert("Score Rejected", isPresented: $showRejectionAlert) {
            Button("Re-score Match") {
                // Reset to scoring screen to re-score
                currentScreen = .scoring
            }
            Button("Cancel", role: .cancel) {
                currentScreen = .idle
                scoringManager = nil
            }
        } message: {
            if let reason = rejectionReason {
                Text("The tournament master rejected your score: \(reason)")
            } else {
                Text("The tournament master rejected your score. Please re-score the match.")
            }
        }
        .alert("Room Closed", isPresented: $showRoomClosedAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(roomClosedReason ?? "The tournament has ended.")
        }
        .alert("Match Unassigned", isPresented: $showMatchUnassignedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(matchUnassignedReason ?? "This match was unassigned by the tournament master.")
        }
        .onAppear {
            setupMessageHandlers()

            // Restore match from saved state if returning to this view
            if let savedMatch = roomManager.activeMatchAssignment,
               roomManager.isInRoom,
               currentMatchId == nil {
                handleAssignedMatch(savedMatch)
            }
        }
        .onChange(of: currentScreen) { screen in
            // Sync hasActiveMatch state for mode switching checks
            roomManager.hasActiveMatch = (currentMatchId != nil && screen == .scoring)

            // Control orientation based on screen
            if screen == .scoring {
                OrientationManager.allowAllOrientations()
            } else {
                OrientationManager.lockToPortrait()
            }
        }
        .onChange(of: currentMatchId) { matchId in
            // Sync hasActiveMatch state for mode switching checks
            roomManager.hasActiveMatch = (matchId != nil && currentScreen == .scoring)
        }
        .onDisappear {
            // Reset to portrait when leaving scoreboard entirely
            OrientationManager.lockToPortrait()
        }
    }

    // MARK: - Setup

    private func setupMessageHandlers() {
        // Handle match assignments
        messageHandler.onMatchAssigned = { message in
            handleAssignedMatch(message)
        }

        // Handle score approval
        messageHandler.onScoreApproved = { matchId in
            if currentMatchId == matchId {
                // Score approved - return to idle
                currentScreen = .idle
                scoringManager = nil
                currentMatchId = nil
                assignedMatch = nil
                roomManager.clearActiveMatch()
            }
        }

        // Handle score rejection
        messageHandler.onScoreRejected = { matchId, reason in
            if currentMatchId == matchId {
                rejectionReason = reason
                showRejectionAlert = true
            }
        }

        // Handle room join confirmation
        messageHandler.onRoomJoined = { success, info in
            if success {
                // Successfully joined - maybe show tournament name
            }
        }

        // Handle room closed by Master
        messageHandler.onRoomClosed = { reason in
            // Clear all match state
            scoringManager = nil
            currentMatchId = nil
            assignedMatch = nil
            currentScreen = .idle

            // Clear persisted match state
            roomManager.clearActiveMatch()

            // Leave the room
            roomManager.leaveRoom()

            // Show alert
            roomClosedReason = reason
            showRoomClosedAlert = true
        }

        // Handle match unassigned by Master
        messageHandler.onMatchUnassigned = { matchId, reason in
            // Only clear if this matches our current match
            if currentMatchId == matchId {
                // Clear match state
                scoringManager = nil
                currentMatchId = nil
                assignedMatch = nil
                currentScreen = .idle

                // Clear persisted match state
                roomManager.clearActiveMatch()

                // Show alert with reason
                matchUnassignedReason = reason
                showMatchUnassignedAlert = true
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            // Room status
            if roomManager.isInRoom, roomManager.currentRoomCode != nil {
                RoomStatusView()
                    .padding(.horizontal)

                // If there's an active match, show resume option
                if let manager = scoringManager, currentMatchId != nil {
                    VStack(spacing: 12) {
                        Text("Match in Progress")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("\(manager.gameState.player1Name) vs \(manager.gameState.player2Name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Score: \(manager.gameState.player1Score) - \(manager.gameState.player2Score)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { currentScreen = .scoring }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Resume Match")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: abandonMatch) {
                            Text("Abandon Match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Text("Waiting for match assignment...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Manual start option
                    VStack(spacing: 12) {
                        Text("Or start a practice match")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { showSetup = true }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Practice Match")
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                }
            } else {
                // Not in room
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.split.2x1.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("Scoreboard")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Start a practice match or join a tournament room")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button(action: { showSetup = true }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Practice Match")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: { showRoomEntry = true }) {
                            HStack {
                                Image(systemName: "door.left.hand.open")
                                Text("Join Tournament Room")
                            }
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
        .padding(.top)
    }

    // MARK: - Awaiting Approval View

    private var awaitingApprovalView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Score Submitted")
                .font(.title2)
                .fontWeight(.bold)

            Text("Waiting for tournament master approval...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let manager = scoringManager {
                // Show final score - set wins for best-of, points otherwise
                HStack(spacing: 24) {
                    VStack {
                        Text(manager.gameState.player1Name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if manager.gameState.bestOf != .none {
                            Text("\(manager.gameState.player1SetWins)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        } else {
                            Text("\(manager.gameState.player1Score)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }

                    Text("-")
                        .font(.title)
                        .foregroundColor(.secondary)

                    VStack {
                        Text(manager.gameState.player2Name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if manager.gameState.bestOf != .none {
                            Text("\(manager.gameState.player2SetWins)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        } else {
                            Text("\(manager.gameState.player2Score)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            ProgressView()
                .scaleEffect(1.2)
                .padding()

            Spacer()

            // Cancel button (only for practice matches)
            if !roomManager.isInRoom {
                Button(action: { currentScreen = .idle }) {
                    Text("Done")
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
        }
    }

    // MARK: - Actions

    private func startMatch(with config: MatchConfiguration) {
        scoringManager = ScoringManager(configuration: config)
        currentScreen = .scoring
        // Ensure landscape is enabled when starting any match
        OrientationManager.allowAllOrientations()
    }

    private func handleMatchComplete(_ state: GameState) {
        if roomManager.isInRoom, let matchId = currentMatchId {
            // Submit score to master via message handler
            guard let winner = state.matchWinner else { return }

            // Convert Player enum to winner name
            let winnerName = winner == .player1 ? state.player1Name : state.player2Name

            messageHandler.submitScore(
                matchId: matchId,
                winner: winnerName,
                player1Score: state.player1Score,
                player2Score: state.player2Score,
                player1SetWins: state.player1SetWins,
                player2SetWins: state.player2SetWins,
                history: state.matchHistory
            )
            currentScreen = .awaitingApproval
        } else {
            // Practice match - just show results briefly then reset
            currentScreen = .idle
            scoringManager = nil
        }
    }

    private func handleCancel() {
        if roomManager.isInRoom && currentMatchId != nil {
            // In tournament mode - just go to idle, keep match state for resume
            currentScreen = .idle
        } else {
            // Practice match - clear everything
            currentScreen = .idle
            scoringManager = nil
        }
    }

    private func abandonMatch() {
        scoringManager = nil
        currentMatchId = nil
        assignedMatch = nil
        roomManager.clearActiveMatch()
    }

    private func handleAssignedMatch(_ message: AssignMatchMessage) {
        // Store match ID for submission
        currentMatchId = UUID(uuidString: message.matchId)

        // Create config from assigned match
        let generation = BeybladeGeneration(byteValue: message.generation) ?? .x
        let matchType = MatchType(byteValue: message.matchType) ?? .points4
        let bestOf = BestOf(byteValue: message.bestOf) ?? .none

        let config = MatchConfiguration(
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: message.ownFinishEnabled,
            player1Name: message.player1Name,
            player2Name: message.player2Name
        )

        assignedMatch = message

        // Persist the match assignment for resume if view is dismissed
        roomManager.activeMatchAssignment = message
        roomManager.saveState()

        startMatch(with: config)
    }
}

// MARK: - Preview

#Preview {
    ScoreboardCoordinator()
}
