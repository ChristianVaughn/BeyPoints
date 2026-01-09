//
// BeyScoreLandingView.swift
// bitchat
//
// Main landing page for BeyPoints - WBO Beyblade Tournament Scoring app.
//

import SwiftUI

struct BeyScoreLandingView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.colorScheme) var colorScheme

    // Navigation state
    @State private var showScoreboard = false
    @State private var showMaster = false
    @State private var showSettings = false

    // Mode switching confirmation alerts
    @State private var showMasterWarning = false
    @State private var showScoreboardWarning = false
    @State private var showMatchInProgressError = false

    // Animation state
    @State private var logoOpacity: Double = 0
    @State private var scoreboardButtonOpacity: Double = 0
    @State private var masterButtonOpacity: Double = 0
    @State private var versionOpacity: Double = 0

    // Manager references for state checking
    @StateObject private var roomManager = TournamentRoomManager.shared
    @StateObject private var tournamentManager = TournamentManager.shared

    private var backgroundColor: Color {
        Color.landingBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with settings button
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.bitchatSystem(size: 22))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                Spacer()

                // Logo and tagline section
                VStack(spacing: 16) {
                    Image("BPLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .opacity(logoOpacity)

                    Text("WBO Beyblade Tournament Scoring")
                        .font(.bitchatSystem(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(logoOpacity)
                }

                Spacer()

                // Main action cards - side by side
                HStack(spacing: 16) {
                    // Scoreboard card
                    Button(action: handleScoreboardTap) {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.split.2x1.fill")
                                .font(.system(size: 32))

                            Text("Scoreboard")
                                .font(.bitchatSystem(size: 16, weight: .semibold, design: .monospaced))

                            Text("Score matches")
                                .font(.bitchatSystem(size: 12, design: .monospaced))
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.primaryBlue(for: colorScheme))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .opacity(scoreboardButtonOpacity)

                    // Master card
                    Button(action: handleMasterTap) {
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))

                            Text("Master")
                                .font(.bitchatSystem(size: 16, weight: .semibold, design: .monospaced))

                            Text("Run tournament")
                                .font(.bitchatSystem(size: 12, design: .monospaced))
                                .opacity(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.primaryOrange(for: colorScheme))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .opacity(masterButtonOpacity)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Version badge
                Text("v1.0 beta")
                    .font(.bitchatSystem(size: 12, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.bottom, 16)
                    .opacity(versionOpacity)
            }
        }
        .onAppear {
            animateEntrance()
        }
        // Full screen covers for each mode
        #if os(iOS)
        .fullScreenCover(isPresented: $showScoreboard) {
            ScoreboardCoordinator()
        }
        .fullScreenCover(isPresented: $showMaster) {
            MasterMainView()
        }
        #else
        .sheet(isPresented: $showScoreboard) {
            ScoreboardCoordinator()
                .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(isPresented: $showMaster) {
            MasterMainView()
                .frame(minWidth: 600, minHeight: 700)
        }
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(profileManager)
        }
        // Mode switching alerts
        .alert("End Tournament?", isPresented: $showScoreboardWarning) {
            Button("Cancel", role: .cancel) { }
            Button("End Tournament", role: .destructive) {
                confirmSwitchToScoreboard()
            }
        } message: {
            Text("You have an active tournament. Switching to Scoreboard mode will end the tournament and disconnect all connected scoreboards.")
        }
        .alert("Leave Room?", isPresented: $showMasterWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Leave Room", role: .destructive) {
                confirmSwitchToMaster()
            }
        } message: {
            Text("You are connected to a tournament room. Switching to Master mode will disconnect you from the current room.")
        }
        .alert("Match In Progress", isPresented: $showMatchInProgressError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Cannot switch modes while scoring a match. Please complete or abandon the current match first.")
        }
    }

    // MARK: - Mode Switching Handlers

    /// Handles tap on Scoreboard button - checks if Master mode has an active tournament.
    private func handleScoreboardTap() {
        if tournamentManager.currentTournament != nil {
            // Has active tournament - warn about ending it
            showScoreboardWarning = true
        } else {
            // No tournament - open directly
            showScoreboard = true
        }
    }

    /// Handles tap on Master button - checks if Scoreboard mode is connected to a room.
    private func handleMasterTap() {
        if roomManager.isInRoom && roomManager.deviceMode == .scoreboard {
            // Connected to a room as scoreboard
            if roomManager.hasActiveMatch {
                // Match in progress - block completely
                showMatchInProgressError = true
            } else {
                // Just connected, no active match - warn about leaving
                showMasterWarning = true
            }
        } else {
            // Not in a room or already in master mode - open directly
            showMaster = true
        }
    }

    /// Confirms switching to Scoreboard mode - ends tournament and notifies all connected devices.
    private func confirmSwitchToScoreboard() {
        // Broadcast room closed to all connected scoreboards
        TournamentMessageHandler.shared.broadcastRoomClosed(reason: "Tournament ended")

        // Clear the tournament (this also leaves the room)
        tournamentManager.clearTournament()

        // Open Scoreboard mode
        showScoreboard = true
    }

    /// Confirms switching to Master mode - leaves the current room.
    private func confirmSwitchToMaster() {
        // Leave the room
        roomManager.leaveRoom()

        // Open Master mode
        showMaster = true
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        // Logo fades in first
        withAnimation(.easeOut(duration: 0.3)) {
            logoOpacity = 1
        }

        // Cards fade in together
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            scoreboardButtonOpacity = 1
            masterButtonOpacity = 1
        }

        // Version badge last
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            versionOpacity = 1
        }
    }
}

// MARK: - Pressable Button Style

/// A button style that scales down slightly when pressed for tactile feedback.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    BeyScoreLandingView()
}
