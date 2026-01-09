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
    @StateObject private var syncManager = ChallongeSyncManager.shared
    @State private var showingCreateTournament = false
    @State private var showingChallongeImport = false
    @State private var selectedTab = 0

    // MARK: - Master Menu

    private var masterMenu: some View {
        Menu {
            // Refresh from Challonge (only if linked)
            if syncManager.isLinked {
                Button {
                    Task { try? await syncManager.refresh() }
                } label: {
                    Label("Refresh from Challonge", systemImage: "arrow.clockwise")
                }

                Divider()
            }

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
        .sheet(isPresented: $showingChallongeImport) {
            ChallongeImportView { tournament in
                print("[BeyScore] MasterMainView: Tournament imported from Challonge")
                tournamentManager.setTournament(tournament)
            }
        }
    }

    // MARK: - iPad No Tournament Layout

    @ViewBuilder
    private var iPadNoTournamentLayout: some View {
        NavigationStack {
            NoTournamentView(
                onCreateTournament: { showingCreateTournament = true },
                onChallongeImport: { showingChallongeImport = true }
            )
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

    @State private var iPadSelectedTab: TournamentTab = .standings

    /// Available tabs for iPad (Devices shown in sidebar, not needed here)
    private var iPadTabs: [TournamentTab] {
        guard let tournament = tournamentManager.currentTournament else {
            return []
        }

        switch tournament.tournamentType {
        case .swiss, .roundRobin:
            if tournament.stageConfig.isMultiStage {
                return [.standings, .matches, .finals]
            } else {
                return [.standings, .matches]
            }
        case .singleElimination, .doubleElimination:
            return [.bracket]
        default:
            return [.bracket]
        }
    }

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
                VStack(spacing: 0) {
                    // Unified picker (no Devices - shown in sidebar)
                    if iPadTabs.count > 1 {
                        Picker("View", selection: $iPadSelectedTab) {
                            ForEach(iPadTabs, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                    }

                    // Content based on selection
                    switch iPadSelectedTab {
                    case .standings:
                        SwissBracketView(
                            tournament: tournament,
                            viewMode: .standings,
                            onMatchSelected: { _ in }
                        )
                    case .matches:
                        SwissBracketView(
                            tournament: tournament,
                            viewMode: .rounds,
                            onMatchSelected: { _ in }
                        )
                    case .finals:
                        SingleEliminationFinalsView(
                            matches: tournament.matches.filter { $0.stage == .finals },
                            finalsType: tournament.stageConfig.finalsType,
                            selectedMatchId: .constant(nil),
                            onMatchSelected: { _ in }
                        )
                    case .bracket:
                        BracketView(
                            tournament: tournament,
                            onMatchSelected: { _ in }
                        )
                    case .devices:
                        // Devices shown in sidebar on iPad
                        EmptyView()
                    }
                }
                .navigationTitle(tournament.name)
                .onAppear {
                    // Set default tab on appear
                    if !iPadTabs.contains(iPadSelectedTab) {
                        iPadSelectedTab = iPadTabs.first ?? .bracket
                    }
                }
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
                    NoTournamentView(
                        onCreateTournament: { showingCreateTournament = true },
                        onChallongeImport: { showingChallongeImport = true }
                    )
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
                            // Refresh from Challonge (only if linked)
                            if syncManager.isLinked {
                                Button {
                                    Task { try? await syncManager.refresh() }
                                } label: {
                                    Label("Refresh from Challonge", systemImage: "arrow.clockwise")
                                }

                                Divider()
                            }

                            Button(role: .destructive) {
                                tournamentManager.clearTournament()
                            } label: {
                                Label("End Tournament", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
        }
    }
}

// MARK: - No Tournament View

struct NoTournamentView: View {
    let onCreateTournament: () -> Void
    let onChallongeImport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 72))
                .foregroundColor(.secondary)

            Text("No Active Tournament")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a tournament or import from Challonge to start managing matches.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button {
                    onCreateTournament()
                } label: {
                    Label("Create Tournament", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onChallongeImport()
                } label: {
                    Label("Import from Challonge", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding()
                }
                .buttonStyle(.bordered)
            }

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

// MARK: - Tournament Tab

/// Unified tabs for tournament navigation
enum TournamentTab: String, CaseIterable {
    case standings = "Standings"
    case matches = "Matches"
    case finals = "Finals"
    case bracket = "Bracket"
    case devices = "Devices"
}

// MARK: - Tournament Dashboard View

struct TournamentDashboardView: View {
    @ObservedObject var tournamentManager: TournamentManager
    @State private var selectedTab: TournamentTab = .standings
    @State private var sheetMatch: TournamentMatch?

    /// Available tabs based on tournament type (iPhone - includes Devices)
    private var availableTabs: [TournamentTab] {
        guard let tournament = tournamentManager.currentTournament else {
            return [.devices]
        }

        switch tournament.tournamentType {
        case .swiss, .roundRobin:
            if tournament.stageConfig.isMultiStage {
                return [.standings, .matches, .finals, .devices]
            } else {
                return [.standings, .matches, .devices]
            }
        case .singleElimination, .doubleElimination:
            return [.bracket, .devices]
        default:
            return [.bracket, .devices]
        }
    }

    /// Default tab based on tournament type
    private var defaultTab: TournamentTab {
        guard let tournament = tournamentManager.currentTournament else {
            return .devices
        }

        switch tournament.tournamentType {
        case .swiss, .roundRobin:
            return .standings
        default:
            return .bracket
        }
    }

    var body: some View {
        if let tournament = tournamentManager.currentTournament {
            VStack(spacing: 0) {
                // Tournament status bar
                TournamentStatusBar(
                    tournament: tournament,
                    pendingApprovals: tournamentManager.pendingSubmissions.count
                )

                // Single unified picker
                Picker("View", selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selection
                switch selectedTab {
                case .standings:
                    SwissBracketView(
                        tournament: tournament,
                        viewMode: .standings,
                        onMatchSelected: { _ in }
                    )
                case .matches:
                    SwissBracketView(
                        tournament: tournament,
                        viewMode: .rounds,
                        onMatchSelected: { _ in }
                    )
                case .finals:
                    SingleEliminationFinalsView(
                        matches: tournament.matches.filter { $0.stage == .finals },
                        finalsType: tournament.stageConfig.finalsType,
                        selectedMatchId: .constant(nil),
                        onMatchSelected: { _ in }
                    )
                case .bracket:
                    BracketView(
                        tournament: tournament,
                        onMatchSelected: { _ in }
                    )
                case .devices:
                    DeviceListView()
                }
            }
            .onAppear {
                // Set default tab on appear
                if !availableTabs.contains(selectedTab) {
                    selectedTab = defaultTab
                }
            }
        } else {
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
    @State private var showingChallongeImport = false

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
                NoTournamentView(
                    onCreateTournament: { showingCreateTournament = true },
                    onChallongeImport: { showingChallongeImport = true }
                )
            }
        }
        .sheet(isPresented: $showingCreateTournament) {
            TournamentCreationView { tournament in
                tournamentManager.setTournament(tournament)
            }
        }
        .sheet(isPresented: $showingChallongeImport) {
            ChallongeImportView { tournament in
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
