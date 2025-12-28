import SwiftUI

struct AppInfoView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // BeyScore mode sheets
    @State private var showScoreboardMode = false
    @State private var showMasterMode = false

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
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    // MARK: - Constants
    private enum Strings {
        static let appName: LocalizedStringKey = "app_info.app_name"
        static let tagline: LocalizedStringKey = "app_info.tagline"

        enum Features {
            static let title: LocalizedStringKey = "app_info.features.title"
            static let offlineComm = AppInfoFeatureInfo(
                icon: "wifi.slash",
                title: "app_info.features.offline.title",
                description: "app_info.features.offline.description"
            )
            static let encryption = AppInfoFeatureInfo(
                icon: "lock.shield",
                title: "app_info.features.encryption.title",
                description: "app_info.features.encryption.description"
            )
            static let extendedRange = AppInfoFeatureInfo(
                icon: "antenna.radiowaves.left.and.right",
                title: "app_info.features.extended_range.title",
                description: "app_info.features.extended_range.description"
            )
            static let mentions = AppInfoFeatureInfo(
                icon: "at",
                title: "app_info.features.mentions.title",
                description: "app_info.features.mentions.description"
            )
            static let favorites = AppInfoFeatureInfo(
                icon: "star.fill",
                title: "app_info.features.favorites.title",
                description: "app_info.features.favorites.description"
            )
            static let geohash = AppInfoFeatureInfo(
                icon: "number",
                title: "app_info.features.geohash.title",
                description: "app_info.features.geohash.description"
            )
        }

        enum Privacy {
            static let title: LocalizedStringKey = "app_info.privacy.title"
            static let noTracking = AppInfoFeatureInfo(
                icon: "eye.slash",
                title: "app_info.privacy.no_tracking.title",
                description: "app_info.privacy.no_tracking.description"
            )
            static let ephemeral = AppInfoFeatureInfo(
                icon: "shuffle",
                title: "app_info.privacy.ephemeral.title",
                description: "app_info.privacy.ephemeral.description"
            )
            static let panic = AppInfoFeatureInfo(
                icon: "hand.raised.fill",
                title: "app_info.privacy.panic.title",
                description: "app_info.privacy.panic.description"
            )
        }

        enum HowToUse {
            static let title: LocalizedStringKey = "app_info.how_to_use.title"
            static let instructions: [LocalizedStringKey] = [
                "app_info.how_to_use.set_nickname",
                "app_info.how_to_use.change_channels",
                "app_info.how_to_use.open_sidebar",
                "app_info.how_to_use.start_dm",
                "app_info.how_to_use.clear_chat",
                "app_info.how_to_use.commands"
            ]
        }

        enum Warning {
            static let title: LocalizedStringKey = "app_info.warning.title"
            static let message: LocalizedStringKey = "app_info.warning.message"
        }
    }
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Custom header for macOS
            HStack {
                Spacer()
                Button("app_info.done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(textColor)
                .padding()
            }
            .background(backgroundColor.opacity(0.95))
            
            ScrollView {
                infoContent
            }
            .background(backgroundColor)
        }
        .frame(width: 600, height: 700)
        .sheet(isPresented: $showScoreboardMode) {
            ScoreboardCoordinator()
                .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(isPresented: $showMasterMode) {
            MasterMainView()
                .frame(minWidth: 600, minHeight: 700)
        }
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
        #else
        NavigationView {
            ScrollView {
                infoContent
            }
            .background(backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bitchatSystem(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(textColor)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("app_info.close")
                }
            }
        }
        .fullScreenCover(isPresented: $showScoreboardMode) {
            ScoreboardCoordinator()
        }
        .fullScreenCover(isPresented: $showMasterMode) {
            MasterMainView()
        }
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
        #endif
    }
    
    @ViewBuilder
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .center, spacing: 8) {
                Text(Strings.appName)
                    .font(.bitchatSystem(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                
                Text(Strings.tagline)
                    .font(.bitchatSystem(size: 16, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            
            // How to Use
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(Strings.HowToUse.title)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(Strings.HowToUse.instructions.enumerated()), id: \.offset) { _, instruction in
                        Text(instruction)
                    }
                }
                .font(.bitchatSystem(size: 14, design: .monospaced))
                .foregroundColor(textColor)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(Strings.Features.title)

                FeatureRow(info: Strings.Features.offlineComm)

                FeatureRow(info: Strings.Features.encryption)

                FeatureRow(info: Strings.Features.extendedRange)

                FeatureRow(info: Strings.Features.favorites)

                FeatureRow(info: Strings.Features.geohash)

                FeatureRow(info: Strings.Features.mentions)
            }

            // BeyScore Tournament System
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.bitchatSystem(size: 20))
                        .foregroundColor(.orange)
                    Text("BeyScore")
                        .font(.bitchatSystem(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)

                Text("Beyblade tournament scoring system with bracket management and multi-device support.")
                    .font(.bitchatSystem(size: 12, design: .monospaced))
                    .foregroundColor(secondaryTextColor)

                HStack(spacing: 12) {
                    Button(action: handleScoreboardTap) {
                        HStack {
                            Image(systemName: "rectangle.split.2x1.fill")
                            Text("Scoreboard")
                        }
                        .font(.bitchatSystem(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button(action: handleMasterTap) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Master")
                        }
                        .font(.bitchatSystem(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            // Privacy
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(Strings.Privacy.title)

                FeatureRow(info: Strings.Privacy.noTracking)

                FeatureRow(info: Strings.Privacy.ephemeral)

                FeatureRow(info: Strings.Privacy.panic)
            }

            // Warning
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(Strings.Warning.title)
                    .foregroundColor(Color.red)
                
                Text(Strings.Warning.message)
                    .font(.bitchatSystem(size: 14, design: .monospaced))
                    .foregroundColor(Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            .padding(.bottom, 16)
            .padding(.horizontal)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Mode Switching Handlers

    /// Handles tap on Scoreboard button - checks if Master mode has an active tournament.
    private func handleScoreboardTap() {
        if tournamentManager.currentTournament != nil {
            // Has active tournament - warn about ending it
            showScoreboardWarning = true
        } else {
            // No tournament - open directly
            showScoreboardMode = true
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
            showMasterMode = true
        }
    }

    /// Confirms switching to Scoreboard mode - ends tournament and notifies all connected devices.
    private func confirmSwitchToScoreboard() {
        // Broadcast room closed to all connected scoreboards
        TournamentMessageHandler.shared.broadcastRoomClosed(reason: "Tournament ended")

        // Clear the tournament (this also leaves the room)
        tournamentManager.clearTournament()

        // Open Scoreboard mode
        showScoreboardMode = true
    }

    /// Confirms switching to Master mode - leaves the current room.
    private func confirmSwitchToMaster() {
        // Leave the room
        roomManager.leaveRoom()

        // Open Master mode
        showMasterMode = true
    }
}

struct AppInfoFeatureInfo {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    init(_ title: LocalizedStringKey) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.bitchatSystem(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(textColor)
            .padding(.top, 8)
    }
}

struct FeatureRow: View {
    let info: AppInfoFeatureInfo
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.icon)
                .font(.bitchatSystem(size: 20))
                .foregroundColor(textColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.bitchatSystem(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(textColor)
                
                Text(info.description)
                    .font(.bitchatSystem(size: 12, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview("Default") {
    AppInfoView()
}

#Preview("Dynamic Type XXL") {
    AppInfoView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("Dynamic Type XS") {
    AppInfoView()
        .environment(\.sizeCategory, .extraSmall)
}
