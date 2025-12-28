//
// BracketView.swift
// bitchat
//
// Visual tournament bracket display for Master mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Visual bracket display for a tournament.
struct BracketView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedMatchId: UUID?

    init(tournament: Tournament, onMatchSelected: ((TournamentMatch) -> Void)? = nil) {
        self.tournament = tournament
        self.onMatchSelected = onMatchSelected
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            HStack(alignment: .center, spacing: 20) {
                ForEach(1...tournament.numberOfRounds, id: \.self) { round in
                    BracketRoundColumn(
                        round: round,
                        matches: tournament.matches(inRound: round),
                        totalRounds: tournament.numberOfRounds,
                        bestOf: tournament.bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchSelected: onMatchSelected
                    )
                }
            }
            .padding()
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
    let onMatchSelected: ((TournamentMatch) -> Void)?

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
                            selectedMatchId = match.id
                            onMatchSelected?(match)
                        }
                    )
                }
            }
        }
        .frame(width: 180)
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
            if match.status == .assigned || match.status == .inProgress {
                Button(role: .destructive) {
                    MatchAssignmentService.shared.cancelAssignment(matchId: match.id)
                } label: {
                    Label("Unassign Match", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var cardBackground: Color {
        switch match.status {
        case .complete:
            return Color(.systemBackground)
        case .inProgress, .assigned:
            return Color.blue.opacity(0.1)
        case .awaitingApproval:
            return Color.orange.opacity(0.1)
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
        .background(isWinner && status == .complete ? Color.green.opacity(0.1) : Color.clear)
    }
}

// MARK: - Match Status Badge

struct MatchStatusBadge: View {
    let status: MatchStatus

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
        case .assigned: return Color.blue.opacity(0.2)
        case .inProgress: return Color.green.opacity(0.2)
        case .awaitingApproval: return Color.orange.opacity(0.2)
        case .complete: return Color.green.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: return .secondary
        case .assigned: return .blue
        case .inProgress: return .green
        case .awaitingApproval: return .orange
        case .complete: return .green
        }
    }
}

// MARK: - Compact Bracket View (for dashboard)

struct CompactBracketView: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress bar
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
                    .fontWeight(.medium)
            }

            // Current round matches
            if tournament.currentRound <= tournament.numberOfRounds {
                let currentMatches = tournament.matches(inRound: tournament.currentRound)
                    .filter { $0.status != .complete }
                    .prefix(3)

                ForEach(Array(currentMatches)) { match in
                    CompactMatchRow(match: match)
                }

                if currentMatches.count == 3 {
                    Text("+ \(tournament.matches(inRound: tournament.currentRound).filter { $0.status != .complete }.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct CompactMatchRow: View {
    let match: TournamentMatch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.player1Name ?? "TBD")
                    .font(.caption)
                Text(match.player2Name ?? "TBD")
                    .font(.caption)
            }

            Spacer()

            MatchStatusBadge(status: match.status)
        }
        .padding(.vertical, 4)
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
