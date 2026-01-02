//
// BeyScoreLandingView.swift
// bitchat
//
// Main landing page for BeyPoints - WBO Beyblade Tournament Scoring app.
//

import SwiftUI

struct BeyScoreLandingView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme

    // Navigation state
    @State private var showScoreboard = false
    @State private var showMaster = false
    @State private var showChat = false
    @State private var showSettings = false

    // Mode switching confirmation alerts
    @State private var showMasterWarning = false
    @State private var showScoreboardWarning = false
    @State private var showMatchInProgressError = false

    // Manager references for state checking
    @StateObject private var roomManager = TournamentRoomManager.shared
    @StateObject private var tournamentManager = TournamentManager.shared

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
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
                            .font(.bitchatSystem(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                Spacer()

                // Title section
                VStack(spacing: 12) {
                    Text("beypoints")
                        .font(.bitchatSystem(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    Text("WBO Beyblade Tournament Scoring")
                        .font(.bitchatSystem(size: 14, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Main action buttons
                VStack(spacing: 16) {
                    // Scoreboard button
                    Button(action: handleScoreboardTap) {
                        HStack {
                            Image(systemName: "rectangle.split.2x1.fill")
                            Text("Scoreboard")
                        }
                        .font(.bitchatSystem(size: 16, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Master button
                    Button(action: handleMasterTap) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Master")
                        }
                        .font(.bitchatSystem(size: 16, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Chat button
                    Button(action: { showChat = true }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Chat")
                        }
                        .font(.bitchatSystem(size: 16, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        // Full screen covers for each mode
        #if os(iOS)
        .fullScreenCover(isPresented: $showScoreboard) {
            ScoreboardCoordinator()
        }
        .fullScreenCover(isPresented: $showMaster) {
            MasterMainView()
        }
        .fullScreenCover(isPresented: $showChat) {
            ContentView()
                .environmentObject(chatViewModel)
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
        .sheet(isPresented: $showChat) {
            ContentView()
                .environmentObject(chatViewModel)
                .frame(minWidth: 600, minHeight: 700)
        }
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(chatViewModel)
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
}

#Preview {
    BeyScoreLandingView()
}
