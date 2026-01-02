//
// MasterMainView.swift
// bitchat
//
// Main view for Tournament Master mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Main view for Tournament Master mode.
struct MasterMainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tournamentManager = TournamentManager.shared
    @State private var showingCreateTournament = false
    @State private var showingAssignMatch = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            Group {
                if tournamentManager.currentTournament == nil {
                    NoTournamentView(onCreateTournament: {
                        showingCreateTournament = true
                    })
                } else {
                    TournamentDashboardView(
                        tournamentManager: tournamentManager,
                        onAssignMatch: {
                            showingAssignMatch = true
                        }
                    )
                }
            }
            .navigationTitle(tournamentManager.currentTournament?.name ?? "Tournament Master")
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
                if tournamentManager.currentTournament != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showingAssignMatch = true
                            } label: {
                                Label("Assign Match", systemImage: "arrow.right.circle")
                            }
                            .disabled(tournamentManager.assignableMatches.isEmpty || tournamentManager.availableScoreboards.isEmpty)

                            Divider()

                            Button(role: .destructive) {
                                tournamentManager.clearTournament()
                            } label: {
                                Label("End Tournament", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }

                    // Approval badge
                    if tournamentManager.hasPendingSubmissions {
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink {
                                ApprovalQueueView()
                                    .navigationTitle("Approvals")
                            } label: {
                                ApprovalBadge()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateTournament) {
                TournamentCreationView { tournament in
                    print("[BeyScore] MasterMainView: Tournament created with roomCode=\(tournament.roomCode)")
                    tournamentManager.setTournament(tournament)
                }
            }
            .sheet(isPresented: $showingAssignMatch) {
                MatchAssignmentView()
            }
        }
    }
}

// MARK: - No Tournament View

struct NoTournamentView: View {
    let onCreateTournament: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 72))
                .foregroundColor(.secondary)

            Text("No Active Tournament")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a tournament to start managing matches and scoreboards.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                onCreateTournament()
            } label: {
                Label("Create Tournament", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
            }
            .buttonStyle(.borderedProminent)

            Spacer()

            // Room code info
            VStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)

                Text("Scoreboards will need the room code to join your tournament.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Tournament Dashboard View

struct TournamentDashboardView: View {
    @ObservedObject var tournamentManager: TournamentManager
    let onAssignMatch: () -> Void

    @State private var selectedSegment = 0

    var body: some View {
        if let tournament = tournamentManager.currentTournament {
            VStack(spacing: 0) {
                // Tournament status bar
                TournamentStatusBar(tournament: tournament)

                // Segment picker
                Picker("View", selection: $selectedSegment) {
                    Text("Bracket").tag(0)
                    Text("Devices").tag(1)
                    if tournamentManager.hasPendingSubmissions {
                        Text("Approvals (\(tournamentManager.pendingSubmissions.count))").tag(2)
                    } else {
                        Text("Approvals").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selection
                switch selectedSegment {
                case 0:
                    BracketView(
                        tournament: tournament,
                        onMatchSelected: { match in
                            // Show match details or quick assign
                        }
                    )
                case 1:
                    DeviceListView()
            case 2:
                ApprovalQueueView()
            default:
                EmptyView()
            }
            }
        } else {
            // Tournament was cleared, show empty state
            EmptyView()
        }
    }
}

// MARK: - Tournament Status Bar

struct TournamentStatusBar: View {
    let tournament: Tournament

    var body: some View {
        VStack(spacing: 8) {
            // Room code
            HStack {
                Text("Room Code:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(tournament.roomCode)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)

                Button {
                    UIPasteboard.general.string = tournament.roomCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            // Progress bar
            HStack {
                ProgressView(value: Double(tournament.completedMatches), total: Double(tournament.totalMatches))
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .frame(maxWidth: .infinity)

                Text("\(tournament.completedMatches)/\(tournament.totalMatches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Quick stats
            HStack(spacing: 16) {
                StatBadge(
                    icon: "person.2",
                    value: "\(tournament.players.count)",
                    label: "Players"
                )

                StatBadge(
                    icon: "rectangle.3.group",
                    value: "R\(tournament.currentRound)",
                    label: "Round"
                )

                StatBadge(
                    icon: "sportscourt",
                    value: "\(tournament.pendingMatches)",
                    label: "Pending"
                )

                if let winner = tournament.winner {
                    StatBadge(
                        icon: "trophy.fill",
                        value: winner,
                        label: "Winner",
                        highlight: true
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(highlight ? .yellow : .secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(highlight ? .yellow : .primary)
                    .lineLimit(1)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - iPad Layout (split view)

struct MasterSplitView: View {
    @StateObject private var tournamentManager = TournamentManager.shared
    @State private var selectedMatch: TournamentMatch?
    @State private var showingCreateTournament = false

    var body: some View {
        NavigationSplitView {
            // Sidebar - devices and approvals
            List {
                if tournamentManager.currentTournament != nil {
                    Section("Room Code") {
                        HStack {
                            Text(tournamentManager.currentTournament?.roomCode ?? "")
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.semibold)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = tournamentManager.currentTournament?.roomCode
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Section("Scoreboards") {
                        CompactDeviceList(tournamentManager: tournamentManager)
                    }

                    if tournamentManager.hasPendingSubmissions {
                        Section("Pending Approvals") {
                            ForEach(tournamentManager.pendingSubmissions.prefix(3)) { submission in
                                PendingSubmissionRow(
                                    submission: submission,
                                    tournament: tournamentManager.currentTournament
                                )
                            }

                            if tournamentManager.pendingSubmissions.count > 3 {
                                NavigationLink {
                                    ApprovalQueueView()
                                } label: {
                                    Text("View all (\(tournamentManager.pendingSubmissions.count))")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tournament")
            .toolbar {
                if tournamentManager.currentTournament == nil {
                    ToolbarItem {
                        Button {
                            showingCreateTournament = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        } detail: {
            if let tournament = tournamentManager.currentTournament {
                BracketView(
                    tournament: tournament,
                    onMatchSelected: { match in
                        selectedMatch = match
                    }
                )
                .navigationTitle(tournament.name)
            } else {
                NoTournamentView(onCreateTournament: {
                    showingCreateTournament = true
                })
            }
        }
        .sheet(isPresented: $showingCreateTournament) {
            TournamentCreationView { tournament in
                tournamentManager.setTournament(tournament)
            }
        }
    }
}

struct PendingSubmissionRow: View {
    let submission: PendingScoreSubmission
    let tournament: Tournament?

    private var match: TournamentMatch? {
        tournament?.match(byId: submission.matchId)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(match?.displayName ?? "Match")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(submission.winner) wins")
                    .font(.subheadline)
            }

            Spacer()

            Text("\(submission.player1FinalScore)-\(submission.player2FinalScore)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MasterMainView()
}
