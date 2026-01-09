//
// SwissBracketView.swift
// bitchat
//
// Swiss tournament standings and matches display.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View mode for SwissBracketView
enum SwissViewMode {
    case standings
    case rounds
}

/// View for displaying a Swiss tournament.
struct SwissBracketView: View {
    let tournament: Tournament
    let viewMode: SwissViewMode
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedRound: Int
    @State private var selectedMatchId: UUID?
    @State private var sheetMatch: TournamentMatch?

    @Environment(\.colorScheme) private var colorScheme

    init(tournament: Tournament, viewMode: SwissViewMode = .standings, onMatchSelected: ((TournamentMatch) -> Void)? = nil) {
        self.tournament = tournament
        self.viewMode = viewMode
        self.onMatchSelected = onMatchSelected
        // Initialize selectedRound to currentSwissRound
        _selectedRound = State(initialValue: tournament.currentSwissRound)
    }

    /// Matches for the preliminary (Swiss) stage
    private var preliminaryMatches: [TournamentMatch] {
        tournament.matches.filter { $0.stage == .group1 || $0.stage == .main }
    }

    var body: some View {
        Group {
            switch viewMode {
            case .standings:
                standingsView
            case .rounds:
                roundsView
            }
        }
        .sheet(item: $sheetMatch) { match in
            MatchDetailSheet(match: match, tournament: tournament)
        }
    }

    // MARK: - Standings View

    private var standingsView: some View {
        ScrollView {
            if tournament.tournamentType == .roundRobin {
                RoundRobinStandingsView(standings: tournament.roundRobinStandings)
                    .padding(.bottom)
            } else {
                StandingsTableView(standings: tournament.swissStandings)
                    .padding(.bottom)
            }
        }
    }

    // MARK: - Rounds View

    private var roundsView: some View {
        VStack(spacing: 0) {
            // Horizontal round picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...tournament.totalPreliminaryRounds, id: \.self) { round in
                        RoundChip(
                            round: round,
                            isSelected: selectedRound == round,
                            isComplete: isRoundComplete(round),
                            isCurrent: round == tournament.currentSwissRound
                        )
                        .onTapGesture {
                            selectedRound = round
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)  // Prevent stroke clipping
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            // Matches for selected round
            ScrollView {
                VStack(spacing: 12) {
                    // Round status header
                    HStack {
                        Text("Round \(selectedRound)")
                            .font(.headline)
                        Spacer()
                        if isRoundComplete(selectedRound) {
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.matchInProgressLight(for: colorScheme))
                                .cornerRadius(4)
                        } else if selectedRound == tournament.currentSwissRound {
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(Color.primaryBlue(for: colorScheme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.matchAssignedLight(for: colorScheme))
                                .cornerRadius(4)
                        } else if selectedRound > tournament.currentSwissRound {
                            Text("Upcoming")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)

                    // Matches
                    ForEach(matchesForRound(selectedRound)) { match in
                        SwissMatchCard(
                            match: match,
                            isSelected: selectedMatchId == match.id,
                            onTap: {
                                selectedMatchId = match.id
                                sheetMatch = match
                                onMatchSelected?(match)
                            }
                        )
                        .padding(.horizontal)
                    }

                    // Empty state for future rounds
                    if matchesForRound(selectedRound).isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Round not yet generated")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Helper Functions

    private func matchesForRound(_ round: Int) -> [TournamentMatch] {
        // Use preliminary matches for Swiss view (group stage matches)
        return preliminaryMatches.filter { $0.roundNumber == round }
            .sorted { $0.matchNumber < $1.matchNumber }
    }

    private func isRoundComplete(_ round: Int) -> Bool {
        let roundMatches = matchesForRound(round)
        guard !roundMatches.isEmpty else { return false }
        return roundMatches.allSatisfy { $0.status == .complete }
    }
}

// MARK: - Round Chip

struct RoundChip: View {
    let round: Int
    let isSelected: Bool
    let isComplete: Bool
    let isCurrent: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("R\(round)")
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(chipBackground)
            .foregroundColor(chipForeground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
    }

    private var chipBackground: Color {
        if isSelected {
            return Color.matchAssigned(for: colorScheme)
        } else if isComplete {
            return Color.winnerHighlight(for: colorScheme)
        } else if isCurrent {
            return Color.matchAssignedLight(for: colorScheme)
        } else {
            return Color(.systemGray5)
        }
    }

    private var chipForeground: Color {
        if isSelected {
            return .blue
        } else if isComplete {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return .secondary
        }
    }

    private var borderColor: Color {
        isSelected ? .blue : .clear
    }
}

// MARK: - Standings Table

struct StandingsTableView: View {
    let standings: [SwissStanding]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: DeviceEnvironment.standingsRankWidth, alignment: .center)
                Text("Player")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Text("W")
                    .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                Text("L")
                    .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                Text("Pts")
                    .frame(width: DeviceEnvironment.standingsPointsWidth, alignment: .center)
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Player rows
            ForEach(Array(sortedStandings.enumerated()), id: \.element.id) { index, standing in
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .frame(width: DeviceEnvironment.standingsRankWidth, alignment: .center)
                        .font(.subheadline)
                        .fontWeight(index < 3 ? .semibold : .regular)
                        .foregroundColor(rankColor(for: index))

                    Text(standing.playerName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .font(.subheadline)
                        .lineLimit(1)

                    Text("\(standing.wins)")
                        .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.green)

                    Text("\(standing.losses)")
                        .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.red)

                    Text(String(format: "%.1f", standing.points))
                        .frame(width: DeviceEnvironment.standingsPointsWidth, alignment: .center)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
            }
        }
    }

    private var sortedStandings: [SwissStanding] {
        standings.sorted {
            if $0.points != $1.points {
                return $0.points > $1.points
            }
            return $0.buchholzScore > $1.buchholzScore
        }
    }

    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .primary
        }
    }
}

// MARK: - Swiss Match Card

struct SwissMatchCard: View {
    let match: TournamentMatch
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showUnassignConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Player 1
            SwissPlayerRow(
                name: match.player1Name ?? "TBD",
                score: match.player1Score,
                isWinner: match.winner == match.player1Name,
                isBye: match.isBye,
                status: match.status
            )

            Divider()

            // Player 2
            SwissPlayerRow(
                name: match.player2Name ?? "BYE",
                score: match.player2Score,
                isWinner: match.winner == match.player2Name,
                isBye: match.isBye,
                status: match.status
            )
        }
        .background(cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            // View Details (always available)
            Button {
                onTap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Divider()

            // Status-specific actions
            switch match.status {
            case .pending:
                if match.isReady && !match.isBye {
                    // Quick assign to available scoreboards
                    let availableDevices = TournamentManager.shared.availableScoreboards.prefix(3)
                    if !availableDevices.isEmpty {
                        ForEach(Array(availableDevices)) { device in
                            Button {
                                quickAssign(to: device)
                            } label: {
                                Label("Assign to \(device.deviceName)", systemImage: "ipad.landscape")
                            }
                        }
                    } else {
                        Button {} label: {
                            Label("No Scoreboards Available", systemImage: "ipad.slash")
                        }
                        .disabled(true)
                    }
                } else if match.isBye {
                    Button {} label: {
                        Label("Bye Match", systemImage: "person.slash")
                    }
                    .disabled(true)
                } else {
                    Button {} label: {
                        Label("Waiting for Round", systemImage: "hourglass")
                    }
                    .disabled(true)
                }

            case .assigned, .inProgress:
                Button(role: .destructive) {
                    showUnassignConfirmation = true
                } label: {
                    Label("Unassign Match", systemImage: "xmark.circle")
                }

            case .awaitingApproval:
                Button {
                    TournamentMessageHandler.shared.approveScore(matchId: match.id)
                } label: {
                    Label("Approve Score", systemImage: "checkmark.circle")
                }

                Button(role: .destructive) {
                    TournamentMessageHandler.shared.rejectScore(matchId: match.id, reason: nil)
                } label: {
                    Label("Reject Score", systemImage: "xmark.circle")
                }

            case .complete:
                Button {} label: {
                    Label("Match Complete", systemImage: "trophy.fill")
                }
                .disabled(true)
            }
        }
        .alert("Unassign Match?", isPresented: $showUnassignConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unassign", role: .destructive) {
                MatchAssignmentService.shared.cancelAssignment(matchId: match.id)
            }
        } message: {
            Text("This will unassign the match from its current scoreboard.")
        }
    }

    private func quickAssign(to device: ConnectedScoreboard) {
        TournamentManager.shared.assignMatch(matchId: match.id, to: device.id)

        if let tournament = TournamentManager.shared.currentTournament {
            let config = tournament.createMatchConfiguration(for: match)
            TournamentMessageHandler.shared.assignMatchToDevice(
                match: match,
                deviceId: device.id,
                config: config
            )
        }
    }

    private var cardBackground: Color {
        switch match.status {
        case .complete:
            return Color(.systemBackground)
        case .inProgress, .assigned:
            return Color.matchAssignedLight(for: colorScheme)
        case .awaitingApproval:
            return Color.matchAwaitingApprovalLight(for: colorScheme)
        default:
            return Color(.systemBackground)
        }
    }

    private var borderColor: Color {
        if isSelected { return .blue }
        switch match.status {
        case .complete: return Color(.separator)
        case .inProgress, .assigned: return .blue
        case .awaitingApproval: return .orange
        default: return Color(.separator)
        }
    }
}

struct SwissPlayerRow: View {
    let name: String
    let score: Int
    let isWinner: Bool
    let isBye: Bool
    let status: MatchStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Winner indicator
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Color.clear.frame(width: 12, height: 12)
            }

            // Player name
            Text(name)
                .font(.subheadline)
                .fontWeight(isWinner ? .semibold : .regular)
                .foregroundColor(isBye && name == "BYE" ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            if status == .complete || status == .inProgress || status == .awaitingApproval {
                Text("\(score)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isWinner ? .green : .primary)
                    .frame(width: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isWinner && status == .complete ? Color.winnerHighlight(for: colorScheme) : Color.clear)
    }
}

// MARK: - Single Elimination Finals View

/// Displays finals bracket in proper single elimination layout
struct SingleEliminationFinalsView: View {
    let matches: [TournamentMatch]
    let finalsType: TournamentType
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: (TournamentMatch) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Matches grouped by round (excluding round 0)
    private var roundGroups: [(round: Int, matches: [TournamentMatch])] {
        let bracketMatches = matches.filter { $0.roundNumber > 0 }
        let grouped = Dictionary(grouping: bracketMatches) { $0.roundNumber }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.matchNumber < $1.matchNumber }) }
    }

    /// 3rd place match (round 0)
    private var thirdPlaceMatch: TournamentMatch? {
        matches.first { $0.roundNumber == 0 }
    }

    /// Total number of bracket rounds (for naming)
    private var totalRounds: Int {
        roundGroups.count
    }

    var body: some View {
        if matches.isEmpty {
            emptyState
        } else {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    // Main bracket
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(roundGroups, id: \.round) { round, roundMatches in
                            VStack(spacing: 0) {
                                // Round header
                                Text(roundLabel(round))
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 12)

                                // Matches for this round with spacing
                                VStack(spacing: spacingForRound(round)) {
                                    ForEach(roundMatches) { match in
                                        BracketMatchCell(
                                            match: match,
                                            isSelected: selectedMatchId == match.id,
                                            onTap: { onMatchSelected(match) }
                                        )
                                    }
                                }
                            }
                            .frame(width: 160)
                        }
                    }

                    // 3rd place match (if exists)
                    if let thirdPlace = thirdPlaceMatch {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("3rd Place Match")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            BracketMatchCell(
                                match: thirdPlace,
                                isSelected: selectedMatchId == thirdPlace.id,
                                onTap: { onMatchSelected(thirdPlace) }
                            )
                            .frame(width: 160)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Finals bracket not yet available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    /// Returns round label based on position from finals
    private func roundLabel(_ round: Int) -> String {
        let distanceFromFinals = totalRounds - round + 1
        switch distanceFromFinals {
        case 1: return "Finals"
        case 2: return "Semifinals"
        case 3: return "Quarterfinals"
        default: return "Round \(round)"
        }
    }

    /// Calculate vertical spacing to align matches with connector lines
    private func spacingForRound(_ round: Int) -> CGFloat {
        // Each subsequent round needs more spacing to align with previous round
        let roundIndex = roundGroups.firstIndex { $0.round == round } ?? 0
        let baseSpacing: CGFloat = 16
        // Double spacing for each round past the first
        return baseSpacing * pow(2, CGFloat(roundIndex))
    }
}

// MARK: - Bracket Match Cell

/// Compact match cell for bracket display
struct BracketMatchCell: View {
    let match: TournamentMatch
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Player 1
            BracketPlayerRow(
                name: match.player1Name ?? "TBD",
                score: match.player1Score,
                isWinner: match.winner == match.player1Name,
                status: match.status
            )

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)

            // Player 2
            BracketPlayerRow(
                name: match.player2Name ?? (match.isBye ? "BYE" : "TBD"),
                score: match.player2Score,
                isWinner: match.winner == match.player2Name,
                status: match.status
            )
        }
        .background(cardBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap()
        }
    }

    private var cardBackground: Color {
        switch match.status {
        case .complete:
            return Color(.systemBackground)
        case .inProgress, .assigned:
            return Color.matchAssignedLight(for: colorScheme)
        case .awaitingApproval:
            return Color.matchAwaitingApprovalLight(for: colorScheme)
        default:
            return Color(.systemBackground)
        }
    }

    private var borderColor: Color {
        if isSelected { return .blue }
        switch match.status {
        case .complete: return Color(.separator)
        case .inProgress, .assigned: return .blue
        case .awaitingApproval: return .orange
        default: return Color(.separator)
        }
    }
}

struct BracketPlayerRow: View {
    let name: String
    let score: Int
    let isWinner: Bool
    let status: MatchStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(isWinner ? .semibold : .regular)
                .foregroundColor(name == "TBD" || name == "BYE" ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if status == .complete || status == .inProgress || status == .awaitingApproval {
                Text("\(score)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isWinner ? .green : .primary)
                    .frame(width: 20, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isWinner && status == .complete ? Color.winnerHighlight(for: colorScheme) : Color.clear)
    }
}

#Preview {
    // Create a sample Swiss tournament
    var tournament = Tournament.create(
        name: "Test Swiss",
        roomCode: "123456",
        players: ["Alice", "Bob", "Charlie", "David", "Eve", "Frank", "Grace", "Henry"],
        tournamentType: .swiss,
        shuffle: true
    )

    // Mark first match as complete
    if !tournament.matches.isEmpty {
        tournament.matches[0].winner = tournament.matches[0].player1Name
        tournament.matches[0].player1Score = 5
        tournament.matches[0].player2Score = 2
        tournament.matches[0].status = .complete
    }

    return NavigationStack {
        SwissBracketView(tournament: tournament) { match in
            print("Selected: \(match.displayName)")
        }
        .navigationTitle(tournament.name)
    }
}
