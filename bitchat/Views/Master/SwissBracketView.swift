//
// SwissBracketView.swift
// bitchat
//
// Swiss tournament standings and matches display.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for displaying a Swiss tournament.
struct SwissBracketView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedTab = 0  // 0=Standings, 1=Rounds
    @State private var selectedRound: Int
    @State private var selectedMatchId: UUID?

    @Environment(\.colorScheme) private var colorScheme

    init(tournament: Tournament, onMatchSelected: ((TournamentMatch) -> Void)? = nil) {
        self.tournament = tournament
        self.onMatchSelected = onMatchSelected
        // Initialize selectedRound to currentSwissRound
        _selectedRound = State(initialValue: tournament.currentSwissRound)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main tab picker
            Picker("View", selection: $selectedTab) {
                Text("Standings").tag(0)
                Text("Rounds").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                // Full scrollable standings
                ScrollView {
                    StandingsTableView(standings: tournament.swissStandings)
                        .padding(.bottom)
                }
            } else {
                // Round selector + matches
                VStack(spacing: 0) {
                    // Horizontal round picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...tournament.totalSwissRounds, id: \.self) { round in
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
        }
    }

    private func matchesForRound(_ round: Int) -> [TournamentMatch] {
        tournament.matches.filter { $0.roundNumber == round }
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
                    .frame(width: 30, alignment: .center)
                Text("Player")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Text("W")
                    .frame(width: 30, alignment: .center)
                Text("L")
                    .frame(width: 30, alignment: .center)
                Text("Pts")
                    .frame(width: 45, alignment: .center)
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Player rows
            ForEach(Array(sortedStandings.enumerated()), id: \.element.id) { index, standing in
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .frame(width: 30, alignment: .center)
                        .font(.subheadline)
                        .fontWeight(index < 3 ? .semibold : .regular)
                        .foregroundColor(rankColor(for: index))

                    Text(standing.playerName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .font(.subheadline)
                        .lineLimit(1)

                    Text("\(standing.wins)")
                        .frame(width: 30, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.green)

                    Text("\(standing.losses)")
                        .frame(width: 30, alignment: .center)
                        .font(.subheadline)
                        .foregroundColor(.red)

                    Text(String(format: "%.1f", standing.points))
                        .frame(width: 45, alignment: .center)
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
            if match.isReady && match.status == .pending {
                onTap()
            }
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

// MARK: - Compact Match Row

struct SwissCompactMatchRow: View {
    let match: TournamentMatch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.player1Name ?? "TBD")
                    .font(.caption)
                    .fontWeight(match.winner == match.player1Name ? .semibold : .regular)
                Text(match.player2Name ?? "TBD")
                    .font(.caption)
                    .fontWeight(match.winner == match.player2Name ? .semibold : .regular)
            }

            Spacer()

            if match.status == .complete {
                Text("\(match.player1Score) - \(match.player2Score)")
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                MatchStatusBadge(status: match.status)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(6)
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
