//
// DoubleEliminationView.swift
// bitchat
//
// Double Elimination bracket display with winners and losers brackets.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for displaying a Double Elimination tournament.
struct DoubleEliminationView: View {
    let tournament: Tournament
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @State private var selectedMatchId: UUID?

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                // Winners Bracket
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("Winners Bracket")
                            .font(.headline)
                    }
                    .padding(.leading)

                    EliminationBracketSection(
                        matches: winnersBracketMatches,
                        bestOf: tournament.bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchSelected: onMatchSelected
                    )
                }

                Divider()
                    .padding(.horizontal)

                // Losers Bracket
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.orange)
                        Text("Losers Bracket")
                            .font(.headline)
                    }
                    .padding(.leading)

                    EliminationBracketSection(
                        matches: losersBracketMatches,
                        bestOf: tournament.bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchSelected: onMatchSelected
                    )
                }

                Divider()
                    .padding(.horizontal)

                // Grand Finals
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.purple)
                        Text("Grand Finals")
                            .font(.headline)
                    }
                    .padding(.leading)

                    GrandFinalsSection(
                        grandFinal: grandFinal,
                        grandFinalReset: grandFinalReset,
                        bestOf: tournament.bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchSelected: onMatchSelected
                    )
                }
            }
            .padding()
        }
    }

    private var winnersBracketMatches: [TournamentMatch] {
        tournament.matches.filter { $0.bracketType == .winners }
            .sorted { ($0.roundNumber, $0.matchNumber) < ($1.roundNumber, $1.matchNumber) }
    }

    private var losersBracketMatches: [TournamentMatch] {
        tournament.matches.filter { $0.bracketType == .losers }
            .sorted { ($0.roundNumber, $0.matchNumber) < ($1.roundNumber, $1.matchNumber) }
    }

    private var grandFinal: TournamentMatch? {
        tournament.matches.first { $0.isGrandFinal && !$0.isGrandFinalReset }
    }

    private var grandFinalReset: TournamentMatch? {
        tournament.matches.first { $0.isGrandFinalReset }
    }
}

// MARK: - Elimination Bracket Section

struct EliminationBracketSection: View {
    let matches: [TournamentMatch]
    let bestOf: BestOf
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: ((TournamentMatch) -> Void)?

    private var rounds: [Int] {
        Array(Set(matches.map { $0.roundNumber })).sorted()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 20) {
                ForEach(rounds, id: \.self) { round in
                    let roundMatches = matches.filter { $0.roundNumber == round }
                        .sorted { $0.matchNumber < $1.matchNumber }

                    BracketRoundColumn(
                        round: round,
                        matches: roundMatches,
                        totalRounds: rounds.count,
                        bestOf: bestOf,
                        selectedMatchId: $selectedMatchId,
                        onMatchSelected: onMatchSelected
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Grand Finals Section

struct GrandFinalsSection: View {
    let grandFinal: TournamentMatch?
    let grandFinalReset: TournamentMatch?
    let bestOf: BestOf
    @Binding var selectedMatchId: UUID?
    let onMatchSelected: ((TournamentMatch) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 20) {
            // Grand Final
            if let gf = grandFinal {
                VStack(spacing: 4) {
                    Text("Grand Final")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    BracketMatchCard(
                        match: gf,
                        bestOf: bestOf,
                        isSelected: selectedMatchId == gf.id,
                        onTap: {
                            selectedMatchId = gf.id
                            onMatchSelected?(gf)
                        }
                    )
                }
            }

            // Arrow
            if grandFinalReset != nil {
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Grand Final Reset
            if let reset = grandFinalReset {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if needsReset {
                            Text("Required")
                                .font(.caption2)
                                .foregroundColor(Color.primaryOrange(for: colorScheme))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.matchAwaitingApprovalLight(for: colorScheme))
                                .cornerRadius(4)
                        } else {
                            Text("If needed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    BracketMatchCard(
                        match: reset,
                        bestOf: bestOf,
                        isSelected: selectedMatchId == reset.id,
                        onTap: {
                            if needsReset {
                                selectedMatchId = reset.id
                                onMatchSelected?(reset)
                            }
                        }
                    )
                    .opacity(needsReset || reset.status == .complete ? 1.0 : 0.5)
                }
            }
        }
        .padding()
    }

    private var needsReset: Bool {
        guard let gf = grandFinal else { return false }
        // If grand final is complete and losers bracket player won
        return gf.status == .complete && gf.winner == gf.player2Name
    }
}

// MARK: - Double Elimination Compact View

struct DoubleEliminationCompactView: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress
            ProgressView(value: Double(completedMatches), total: Double(tournament.matches.count))
                .progressViewStyle(.linear)
                .tint(.green)

            HStack {
                Text("\(completedMatches)/\(tournament.matches.count) matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(currentPhase)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Current matches
            VStack(spacing: 4) {
                ForEach(pendingMatches.prefix(3)) { match in
                    CompactMatchRow(match: match)
                }
            }

            if pendingMatches.count > 3 {
                Text("+ \(pendingMatches.count - 3) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var completedMatches: Int {
        tournament.matches.filter { $0.status == .complete }.count
    }

    private var pendingMatches: [TournamentMatch] {
        tournament.matches.filter {
            $0.status != .complete && $0.isReady
        }
    }

    private var currentPhase: String {
        if tournament.matches.contains(where: { $0.isGrandFinal && $0.status != .complete && $0.isReady }) {
            return "Grand Finals"
        } else if tournament.matches.filter({ $0.bracketType == .winners }).allSatisfy({ $0.status == .complete }) {
            return "Losers Bracket"
        } else {
            return "Winners Bracket"
        }
    }
}

#Preview {
    // Create a sample Double Elimination tournament
    let tournament = Tournament.create(
        name: "Test Double Elim",
        roomCode: "123456",
        players: ["Alice", "Bob", "Charlie", "David", "Eve", "Frank", "Grace", "Henry"],
        tournamentType: .doubleElimination,
        shuffle: false
    )

    return NavigationStack {
        DoubleEliminationView(tournament: tournament) { match in
            print("Selected: \(match.displayName)")
        }
        .navigationTitle(tournament.name)
    }
}
