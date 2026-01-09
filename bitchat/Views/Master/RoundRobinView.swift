//
// RoundRobinView.swift
// bitchat
//
// Round Robin tournament grid and standings display.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for displaying a Round Robin tournament.
struct RoundRobinView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedTab = 0  // 0=Standings, 1=Matches
    @State private var selectedMatchId: UUID?
    @State private var sheetMatch: TournamentMatch?

    var body: some View {
        VStack(spacing: 0) {
            // Main tab picker
            Picker("View", selection: $selectedTab) {
                Text("Standings").tag(0)
                Text("Matches").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                // Full scrollable standings
                ScrollView {
                    RoundRobinStandingsView(standings: tournament.roundRobinStandings)
                        .padding(.bottom)
                }
            } else {
                // Matches with grid and list
                ScrollView {
                    VStack(spacing: 16) {
                        // Progress indicator
                        HStack {
                            Text("\(completedCount)/\(tournament.matches.count) matches")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView(value: Double(completedCount), total: Double(tournament.matches.count))
                                .frame(width: 100)
                        }
                        .padding(.horizontal)

                        // Match grid
                        RoundRobinGrid(
                            players: tournament.players,
                            matches: tournament.matches,
                            selectedMatchId: $selectedMatchId,
                            onMatchSelected: { match in
                                sheetMatch = match
                                onMatchSelected?(match)
                            }
                        )
                        .padding(.horizontal)

                        // Match list by round
                        RoundRobinMatchList(
                            matches: tournament.matches,
                            selectedMatchId: $selectedMatchId,
                            onMatchSelected: { match in
                                sheetMatch = match
                                onMatchSelected?(match)
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(item: $sheetMatch) { match in
            MatchDetailSheet(match: match, tournament: tournament)
        }
    }

    private var completedCount: Int {
        tournament.matches.filter { $0.status == .complete }.count
    }
}

// MARK: - Round Robin Standings

struct RoundRobinStandingsView: View {
    let standings: [RoundRobinStanding]

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
                Text("+/-")
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
                        .truncationMode(.tail)

                    Text("\(standing.wins)")
                        .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.green)

                    Text("\(standing.losses)")
                        .frame(width: DeviceEnvironment.standingsStatWidth, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.red)

                    Text(standing.pointDifferential >= 0 ? "+\(standing.pointDifferential)" : "\(standing.pointDifferential)")
                        .frame(width: DeviceEnvironment.standingsPointsWidth, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(standing.pointDifferential >= 0 ? .green : .red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
            }
        }
    }

    private var sortedStandings: [RoundRobinStanding] {
        standings.sorted {
            if $0.wins != $1.wins {
                return $0.wins > $1.wins
            }
            return $0.pointDifferential > $1.pointDifferential
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

// MARK: - Round Robin Grid

struct RoundRobinGrid: View {
    let players: [String]
    let matches: [TournamentMatch]
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: ((TournamentMatch) -> Void)?

    private var cellSize: CGFloat { DeviceEnvironment.roundRobinCellSize }
    private var headerWidth: CGFloat { DeviceEnvironment.roundRobinHeaderWidth }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                // Header row with player names (rotated)
                HStack(spacing: 0) {
                    // Empty corner cell
                    Color.clear
                        .frame(width: headerWidth, height: cellSize)

                    ForEach(players, id: \.self) { player in
                        Text(String(player.prefix(3)).uppercased())
                            .font(.caption2.bold())
                            .frame(width: cellSize, height: cellSize)
                            .rotationEffect(.degrees(-45))
                    }
                }

                // Grid rows
                ForEach(players, id: \.self) { player1 in
                    HStack(spacing: 0) {
                        // Row header
                        Text(player1)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: headerWidth, alignment: .leading)
                            .padding(.leading, 4)

                        // Cells
                        ForEach(players, id: \.self) { player2 in
                            GridCell(
                                player1: player1,
                                player2: player2,
                                matches: matches,
                                selectedMatchId: $selectedMatchId,
                                onMatchSelected: onMatchSelected
                            )
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

struct GridCell: View {
    let player1: String
    let player2: String
    let matches: [TournamentMatch]
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var cellSize: CGFloat { DeviceEnvironment.roundRobinCellSize }

    private var match: TournamentMatch? {
        matches.first { m in
            (m.player1Name == player1 && m.player2Name == player2) ||
            (m.player1Name == player2 && m.player2Name == player1)
        }
    }

    var body: some View {
        Group {
            if player1 == player2 {
                // Diagonal - can't play yourself
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: cellSize, height: cellSize)
            } else if let match = match {
                Button {
                    selectedMatchId = match.id
                    onMatchSelected?(match)
                } label: {
                    cellContent(for: match)
                }
                .buttonStyle(.plain)
            } else {
                // No match found
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(width: cellSize, height: cellSize)
            }
        }
    }

    @ViewBuilder
    private func cellContent(for match: TournamentMatch) -> some View {
        ZStack {
            Rectangle()
                .fill(cellBackground(for: match))
                .frame(width: cellSize, height: cellSize)

            if match.status == .complete {
                // Show result
                let isP1 = match.player1Name == player1
                let score = isP1 ? match.player1Score : match.player2Score
                let won = match.winner == player1

                Text("\(score)")
                    .font(.caption.bold())
                    .foregroundColor(won ? .green : .red)
            } else if match.status == .inProgress || match.status == .assigned {
                Image(systemName: "play.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .overlay(
            Rectangle()
                .stroke(selectedMatchId == match.id ? Color.blue : Color(.separator), lineWidth: selectedMatchId == match.id ? 2 : 0.5)
        )
    }

    private func cellBackground(for match: TournamentMatch) -> Color {
        switch match.status {
        case .complete:
            return match.winner == player1 ? Color.winnerHighlight(for: colorScheme) : Color.loserHighlight(for: colorScheme)
        case .inProgress, .assigned:
            return Color.matchAssignedLight(for: colorScheme)
        case .awaitingApproval:
            return Color.matchAwaitingApprovalLight(for: colorScheme)
        default:
            return Color(.systemBackground)
        }
    }
}

// MARK: - Match List by Round

struct RoundRobinMatchList: View {
    let matches: [TournamentMatch]
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: ((TournamentMatch) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matches")
                .font(.headline)

            ForEach(groupedByRound.keys.sorted(), id: \.self) { round in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Round \(round)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(groupedByRound[round] ?? []) { match in
                        RoundRobinMatchRow(
                            match: match,
                            isSelected: selectedMatchId == match.id,
                            onTap: {
                                selectedMatchId = match.id
                                onMatchSelected?(match)
                            }
                        )
                    }
                }
            }
        }
    }

    private var groupedByRound: [Int: [TournamentMatch]] {
        Dictionary(grouping: matches, by: { $0.roundNumber })
    }
}

struct RoundRobinMatchRow: View {
    let match: TournamentMatch
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showUnassignConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if match.winner == match.player1Name {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    Text(match.player1Name ?? "TBD")
                        .font(.subheadline)
                        .fontWeight(match.winner == match.player1Name ? .semibold : .regular)
                }
                HStack {
                    if match.winner == match.player2Name {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    Text(match.player2Name ?? "TBD")
                        .font(.subheadline)
                        .fontWeight(match.winner == match.player2Name ? .semibold : .regular)
                }
            }

            Spacer()

            if match.status == .complete {
                Text("\(match.player1Score) - \(match.player2Score)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                MatchStatusBadge(status: match.status)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.selectionBackground(for: colorScheme) : Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.primaryBlue(for: colorScheme) : Color.clear, lineWidth: 2)
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
                if match.isReady {
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
                } else {
                    Button {} label: {
                        Label("Waiting for Players", systemImage: "hourglass")
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
}

// MARK: - Group Round Robin View

struct GroupRoundRobinView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedTab = 0
    @State private var sheetMatch: TournamentMatch?

    var body: some View {
        if tournament.currentStage == .finals {
            // Show finals bracket
            BracketView(tournament: tournament, onMatchSelected: onMatchSelected)
        } else {
            // Show groups
            VStack(spacing: 0) {
                // Group tabs
                Picker("Group", selection: $selectedTab) {
                    Text("Group A").tag(0)
                    Text("Group B").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Group content
                TabView(selection: $selectedTab) {
                    GroupStageView(
                        groupName: "Group A",
                        players: tournament.group1Players,
                        matches: tournament.matches.filter { $0.stage == .group1 },
                        standings: tournament.groupStandings(for: .group1),
                        onMatchSelected: { match in
                            sheetMatch = match
                            onMatchSelected?(match)
                        }
                    )
                    .tag(0)

                    GroupStageView(
                        groupName: "Group B",
                        players: tournament.group2Players,
                        matches: tournament.matches.filter { $0.stage == .group2 },
                        standings: tournament.groupStandings(for: .group2),
                        onMatchSelected: { match in
                            sheetMatch = match
                            onMatchSelected?(match)
                        }
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .sheet(item: $sheetMatch) { match in
                MatchDetailSheet(match: match, tournament: tournament)
            }
        }
    }
}

struct GroupStageView: View {
    let groupName: String
    let players: [String]
    let matches: [TournamentMatch]
    let standings: [RoundRobinStanding]
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedMatchId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Group header with progress
                HStack {
                    Text(groupName)
                        .font(.title2.bold())
                    Spacer()
                    Text("\(completedCount)/\(matches.count) matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Standings
                RoundRobinStandingsView(standings: standings)
                    .padding(.horizontal)

                // Match list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Matches")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(matches) { match in
                        RoundRobinMatchRow(
                            match: match,
                            isSelected: selectedMatchId == match.id,
                            onTap: {
                                selectedMatchId = match.id
                                onMatchSelected?(match)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var completedCount: Int {
        matches.filter { $0.status == .complete }.count
    }
}

#Preview {
    // Create a sample Round Robin tournament
    let tournament = Tournament.create(
        name: "Test Round Robin",
        roomCode: "123456",
        players: ["Alice", "Bob", "Charlie", "David"],
        tournamentType: .roundRobin,
        shuffle: false
    )

    return NavigationStack {
        RoundRobinView(tournament: tournament) { match in
            print("Selected: \(match.displayName)")
        }
        .navigationTitle(tournament.name)
    }
}
