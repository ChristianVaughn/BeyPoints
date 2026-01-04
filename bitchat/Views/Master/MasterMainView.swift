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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var tournamentManager = TournamentManager.shared
    @State private var showingCreateTournament = false
    @State private var selectedTab = 0

    // MARK: - Master Menu

    private var masterMenu: some View {
        Menu {
            Button(role: .destructive) {
                tournamentManager.clearTournament()
            } label: {
                Label("End Tournament", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    var body: some View {
        Group {
            // Use split view on iPad with regular width, but only when tournament exists
            if DeviceEnvironment.isIPad && horizontalSizeClass == .regular && tournamentManager.currentTournament != nil {
                iPadSplitLayout
            } else if DeviceEnvironment.isIPad && horizontalSizeClass == .regular {
                // iPad with no tournament - simple full screen view
                iPadNoTournamentLayout
            } else {
                iPhoneStackLayout
            }
        }
        .sheet(isPresented: $showingCreateTournament) {
            TournamentCreationView { tournament in
                print("[BeyScore] MasterMainView: Tournament created with roomCode=\(tournament.roomCode)")
                tournamentManager.setTournament(tournament)
            }
        }
    }

    // MARK: - iPad No Tournament Layout

    @ViewBuilder
    private var iPadNoTournamentLayout: some View {
        NavigationStack {
            NoTournamentView(onCreateTournament: {
                showingCreateTournament = true
            })
            .navigationTitle("Tournament Master")
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
            }
        }
    }

    // MARK: - iPad Split Layout

    @ViewBuilder
    private var iPadSplitLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar - only shown when tournament exists
            MasterSidebarList(
                tournamentManager: tournamentManager,
                onCreateTournament: { showingCreateTournament = true }
            )
            .navigationTitle("Tournament")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    masterMenu
                }
            }
        } detail: {
            if let tournament = tournamentManager.currentTournament {
                BracketView(
                    tournament: tournament,
                    onMatchSelected: { _ in }
                )
                .navigationTitle(tournament.name)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - iPhone Stack Layout

    @ViewBuilder
    private var iPhoneStackLayout: some View {
        NavigationStack {
            Group {
                if tournamentManager.currentTournament == nil {
                    NoTournamentView(onCreateTournament: {
                        showingCreateTournament = true
                    })
                } else {
                    TournamentDashboardView(
                        tournamentManager: tournamentManager
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
                            Button(role: .destructive) {
                                tournamentManager.clearTournament()
                            } label: {
                                Label("End Tournament", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    // iPhone approval flow: tap match in bracket to view and approve
                    // (ApprovalBadge removed - pending count shown in TournamentStatusBar)
                }
            }
            .sheet(isPresented: $showingCreateTournament) {
                TournamentCreationView { tournament in
                    print("[BeyScore] MasterMainView: Tournament created with roomCode=\(tournament.roomCode)")
                    tournamentManager.setTournament(tournament)
                }
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
    @State private var selectedSegment = 0
    @State private var sheetMatch: TournamentMatch?

    var body: some View {
        if let tournament = tournamentManager.currentTournament {
            VStack(spacing: 0) {
                // Tournament status bar
                TournamentStatusBar(
                    tournament: tournament,
                    pendingApprovals: tournamentManager.pendingSubmissions.count
                )

                // Segment picker (iPhone: Bracket and Devices only, approve via match tap)
                Picker("View", selection: $selectedSegment) {
                    Text("Bracket").tag(0)
                    Text("Devices").tag(1)
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
    var pendingApprovals: Int = 0

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
                    label: "Queued"
                )

                // Pending approvals indicator
                if pendingApprovals > 0 {
                    StatBadge(
                        icon: "checkmark.circle",
                        value: "\(pendingApprovals)",
                        label: "Approve",
                        highlight: true
                    )
                }

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

// MARK: - Master Sidebar List (iPad)

struct MasterSidebarList: View {
    @ObservedObject var tournamentManager: TournamentManager
    @ObservedObject var messageHandler: TournamentMessageHandler
    let onCreateTournament: () -> Void

    init(tournamentManager: TournamentManager, messageHandler: TournamentMessageHandler, onCreateTournament: @escaping () -> Void) {
        self.tournamentManager = tournamentManager
        self.messageHandler = messageHandler
        self.onCreateTournament = onCreateTournament
    }

    @MainActor
    init(tournamentManager: TournamentManager, onCreateTournament: @escaping () -> Void) {
        self.tournamentManager = tournamentManager
        self.messageHandler = .shared
        self.onCreateTournament = onCreateTournament
    }

    var body: some View {
        List {
            if let tournament = tournamentManager.currentTournament {
                // Room code section
                Section("Room Code") {
                    HStack {
                        Text(tournament.roomCode)
                            .font(.system(.title3, design: .monospaced))
                            .fontWeight(.semibold)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = tournament.roomCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // Tournament progress
                Section("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(tournament.completedMatches), total: Double(tournament.totalMatches))
                            .progressViewStyle(.linear)
                            .tint(.green)

                        HStack {
                            Text("\(tournament.completedMatches)/\(tournament.totalMatches) matches")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("Round \(tournament.currentRound)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Scoreboards section
                Section("Scoreboards") {
                    CompactDeviceList(tournamentManager: tournamentManager)
                }

                // Pending approvals
                if tournamentManager.hasPendingSubmissions {
                    Section("Pending Approvals") {
                        ForEach(tournamentManager.pendingSubmissions.prefix(5)) { submission in
                            PendingSubmissionRow(
                                submission: submission,
                                tournament: tournament,
                                onApprove: {
                                    messageHandler.approveScore(matchId: submission.matchId)
                                },
                                onReject: {
                                    messageHandler.rejectScore(matchId: submission.matchId, reason: nil)
                                }
                            )
                        }

                        if tournamentManager.pendingSubmissions.count > 5 {
                            NavigationLink {
                                ApprovalQueueView()
                            } label: {
                                Text("View all (\(tournamentManager.pendingSubmissions.count))")
                            }
                        }
                    }
                }
            }
            // Note: No "else" case needed - sidebar only shown when tournament exists
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - iPad Layout (split view - legacy)

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
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    private var match: TournamentMatch? {
        tournament?.match(byId: submission.matchId)
    }

    private var isBestOf: Bool {
        submission.player1SetWins > 0 || submission.player2SetWins > 0
    }

    private var scoreText: String {
        if isBestOf {
            return "\(submission.player1SetWins) - \(submission.player2SetWins)"
        } else {
            return "\(submission.player1FinalScore) - \(submission.player2FinalScore)"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(match?.displayName ?? "Match")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(match?.player1Name ?? "P1")
                        .fontWeight(submission.winner == match?.player1Name ? .bold : .regular)
                    Text(scoreText)
                        .foregroundColor(.secondary)
                    Text(match?.player2Name ?? "P2")
                        .fontWeight(submission.winner == match?.player2Name ? .bold : .regular)
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(submission.winner) wins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Approve/Reject buttons if handlers provided
            if onApprove != nil || onReject != nil {
                HStack(spacing: 8) {
                    if let reject = onReject {
                        Button(action: reject) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }

                    if let approve = onApprove {
                        Button(action: approve) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MasterMainView()
}
