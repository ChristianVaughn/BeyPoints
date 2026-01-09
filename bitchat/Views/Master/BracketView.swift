//
// BracketView.swift
// bitchat
//
// Visual tournament bracket display for Master mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Visual bracket display for a tournament.
/// Routes to the appropriate view based on tournament type.
struct BracketView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedMatchId: UUID?

    init(tournament: Tournament, onMatchSelected: ((TournamentMatch) -> Void)? = nil) {
        self.tournament = tournament
        self.onMatchSelected = onMatchSelected
    }

    var body: some View {
        switch tournament.tournamentType {
        case .singleElimination:
            SingleEliminationBracketView(
                tournament: tournament,
                onMatchSelected: onMatchSelected
            )

        case .doubleElimination:
            DoubleEliminationView(
                tournament: tournament,
                onMatchSelected: onMatchSelected
            )

        case .swiss:
            SwissBracketView(
                tournament: tournament,
                onMatchSelected: onMatchSelected
            )

        case .roundRobin:
            RoundRobinView(
                tournament: tournament,
                onMatchSelected: onMatchSelected
            )

        case .groupRoundRobin:
            GroupRoundRobinView(
                tournament: tournament,
                onMatchSelected: onMatchSelected
            )
        }
    }
}

/// Single Elimination bracket view (original BracketView logic).
struct SingleEliminationBracketView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedMatchId: UUID?
    @State private var sheetMatch: TournamentMatch?

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            HStack(alignment: .center, spacing: 20) {
                ForEach(1...max(1, tournament.numberOfRounds), id: \.self) { round in
                    BracketRoundColumn(
                        round: round,
                        matches: tournament.matches(inRound: round),
                        totalRounds: tournament.numberOfRounds,
                        bestOf: tournament.bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchTap: { match in
                            selectedMatchId = match.id
                            sheetMatch = match
                            onMatchSelected?(match)
                        }
                    )
                }
            }
            .padding()
        }
        .sheet(item: $sheetMatch) { match in
            MatchDetailSheet(match: match, tournament: tournament)
        }
    }
}

// MARK: - Bracket Round Column

struct BracketRoundColumn: View {
    let round: Int
    let matches: [TournamentMatch]
    let totalRounds: Int
    let bestOf: BestOf
    @Binding var selectedMatchId: UUID?
    let onMatchTap: ((TournamentMatch) -> Void)?

    private var roundName: String {
        if round == totalRounds {
            return "Final"
        } else if round == totalRounds - 1 && totalRounds > 1 {
            return "Semifinal"
        } else if round == totalRounds - 2 && totalRounds > 2 {
            return "Quarterfinal"
        } else {
            return "Round \(round)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Round header
            Text(roundName)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)

            // Matches with spacing
            VStack(spacing: matchSpacing) {
                ForEach(matches) { match in
                    BracketMatchCard(
                        match: match,
                        bestOf: bestOf,
                        isSelected: selectedMatchId == match.id,
                        onTap: {
                            onMatchTap?(match)
                        }
                    )
                }
            }
        }
        .frame(width: DeviceEnvironment.minBracketColumnWidth)
    }

    private var matchSpacing: CGFloat {
        // Increase spacing between matches for later rounds
        CGFloat(pow(2.0, Double(round - 1))) * 20
    }
}

// MARK: - Bracket Match Card

struct BracketMatchCard: View {
    let match: TournamentMatch
    let bestOf: BestOf
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showUnassignConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Player 1
            PlayerSlot(
                name: match.player1Name,
                score: match.player1Score,
                setWins: match.player1SetWins,
                bestOf: bestOf,
                isWinner: match.winner == match.player1Name,
                status: match.status
            )

            Divider()

            // Player 2
            PlayerSlot(
                name: match.player2Name,
                score: match.player2Score,
                setWins: match.player2SetWins,
                bestOf: bestOf,
                isWinner: match.winner == match.player2Name,
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
        if isSelected {
            return .blue
        }
        switch match.status {
        case .complete:
            return Color(.separator)
        case .inProgress, .assigned:
            return .blue
        case .awaitingApproval:
            return .orange
        default:
            return Color(.separator)
        }
    }
}

// MARK: - Player Slot

struct PlayerSlot: View {
    let name: String?
    let score: Int
    let setWins: Int
    let bestOf: BestOf
    let isWinner: Bool
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
                Color.clear
                    .frame(width: 12, height: 12)
            }

            // Player name
            Text(name ?? "TBD")
                .font(.subheadline)
                .fontWeight(isWinner ? .semibold : .regular)
                .foregroundColor(name == nil ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Score (if match has started)
            if status == .complete || status == .inProgress || status == .awaitingApproval {
                if bestOf != .none {
                    // Best-of match: show set wins as primary score
                    Text("\(setWins)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isWinner ? .green : .primary)
                        .frame(width: 24, alignment: .trailing)
                } else {
                    // Single game: show game points
                    Text("\(score)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isWinner ? .green : .primary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isWinner && status == .complete ? Color.winnerHighlight(for: colorScheme) : Color.clear)
    }
}

// MARK: - Match Status Badge

struct MatchStatusBadge: View {
    let status: MatchStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: return Color(.systemGray5)
        case .assigned: return Color.matchAssigned(for: colorScheme)
        case .inProgress: return Color.matchInProgress(for: colorScheme)
        case .awaitingApproval: return Color.matchAwaitingApproval(for: colorScheme)
        case .complete: return Color.matchComplete(for: colorScheme)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: return .secondary
        case .assigned: return Color.primaryBlue(for: colorScheme)
        case .inProgress: return .green
        case .awaitingApproval: return Color.primaryOrange(for: colorScheme)
        case .complete: return .green
        }
    }
}

#Preview {
    let tournament = Tournament.create(
        name: "Test Tournament",
        roomCode: "123456",
        players: ["Player 1", "Player 2", "Player 3", "Player 4", "Player 5", "Player 6", "Player 7", "Player 8"],
        generation: .x,
        matchType: .points4,
        bestOf: .none,
        ownFinishEnabled: false,
        shuffle: false
    )

    return NavigationStack {
        BracketView(tournament: tournament) { match in
            print("Selected: \(match.displayName)")
        }
        .navigationTitle(tournament.name)
    }
}
