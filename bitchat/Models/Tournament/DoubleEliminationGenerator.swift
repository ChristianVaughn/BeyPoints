//
// DoubleEliminationGenerator.swift
// bitchat
//
// Double Elimination bracket generation with losers bracket and grand finals.
// Part of BeyScore Tournament System.
//

import Foundation

/// Generates Double Elimination tournament brackets.
enum DoubleEliminationGenerator {

    // MARK: - Bracket Generation

    /// Generates a complete double elimination bracket.
    /// Includes winners bracket, losers bracket, and grand finals with potential reset.
    static func generateBracket(players: [String], shuffle: Bool = false) -> [TournamentMatch] {
        guard players.count >= 2 else { return [] }

        let playerList = shuffle ? players.shuffled() : players

        // Generate winners bracket (same as single elimination)
        var winnersBracket = generateWinnersBracket(players: playerList)

        // Generate losers bracket
        let winnersRoundCount = winnersBracket.map { $0.roundNumber }.max() ?? 0
        var losersBracket = generateLosersBracket(
            bracketSize: nextPowerOf2(playerList.count),
            winnersRoundCount: winnersRoundCount,
            winnersBracket: winnersBracket
        )

        // Link winners bracket losers to losers bracket
        linkWinnersToLosers(winnersBracket: &winnersBracket, losersBracket: &losersBracket)

        // Generate grand finals
        let maxWinnersRound = winnersBracket.map { $0.roundNumber }.max() ?? 0
        let maxLosersRound = losersBracket.map { $0.roundNumber }.max() ?? 0
        let grandFinalRound = maxWinnersRound + maxLosersRound + 1

        var grandFinal = TournamentMatch(
            roundNumber: grandFinalRound,
            matchNumber: 0,
            bracketType: .grandFinal
        )
        grandFinal.isGrandFinal = true

        var grandFinalReset = TournamentMatch(
            roundNumber: grandFinalRound + 1,
            matchNumber: 0,
            bracketType: .grandFinal
        )
        grandFinalReset.isGrandFinal = true
        grandFinalReset.isGrandFinalReset = true

        // Link finals winner and losers bracket winner to grand final
        if let winnersFinalist = winnersBracket.first(where: { $0.roundNumber == maxWinnersRound }) {
            if let index = winnersBracket.firstIndex(where: { $0.id == winnersFinalist.id }) {
                winnersBracket[index].nextMatchId = grandFinal.id
                winnersBracket[index].nextMatchSlot = .player1
            }
        }
        if let losersFinalist = losersBracket.first(where: { $0.roundNumber == maxLosersRound }) {
            if let index = losersBracket.firstIndex(where: { $0.id == losersFinalist.id }) {
                losersBracket[index].nextMatchId = grandFinal.id
                losersBracket[index].nextMatchSlot = .player2
            }
        }

        // Link grand final to reset
        grandFinal.nextMatchId = grandFinalReset.id

        return winnersBracket + losersBracket + [grandFinal, grandFinalReset]
    }

    // MARK: - Winners Bracket

    private static func generateWinnersBracket(players: [String]) -> [TournamentMatch] {
        var matches = BracketGenerator.generateBracket(players: players)

        // Mark all as winners bracket
        for i in 0..<matches.count {
            matches[i].bracketType = .winners
        }

        return matches
    }

    // MARK: - Losers Bracket

    /// Generates the losers bracket structure.
    /// Losers bracket rounds alternate between:
    /// - Minor rounds: Only losers bracket players
    /// - Major rounds: Losers bracket survivor + drop-in from winners
    private static func generateLosersBracket(
        bracketSize: Int,
        winnersRoundCount: Int,
        winnersBracket: [TournamentMatch]
    ) -> [TournamentMatch] {
        var matches: [TournamentMatch] = []
        var losersRound = 1
        var matchNumber = 0

        // For an 8-player bracket (3 winners rounds):
        // LR1: 2 matches (R1 losers)
        // LR2: 2 matches (LR1 winners vs R2 losers drop-ins)
        // LR3: 1 match (LR2 winners)
        // LR4: 1 match (LR3 winner vs Semifinal loser)
        // LR5: 1 match (LR4 winner vs Finals loser) - Losers Final

        // Calculate losers bracket structure
        // First round: half of bracket size / 2 matches
        let firstRoundMatches = bracketSize / 4

        // Create first losers round (round 1 losers face each other)
        for _ in 0..<firstRoundMatches {
            let match = TournamentMatch(
                roundNumber: losersRound,
                matchNumber: matchNumber,
                bracketType: .losers
            )
            matches.append(match)
            matchNumber += 1
        }
        losersRound += 1

        // Subsequent rounds
        var currentMatches = firstRoundMatches
        for _ in 2...winnersRoundCount {
            // Minor round: survivors from previous losers round
            if currentMatches > 1 {
                let minorRoundMatches = currentMatches / 2
                for _ in 0..<minorRoundMatches {
                    let match = TournamentMatch(
                        roundNumber: losersRound,
                        matchNumber: matchNumber,
                        bracketType: .losers
                    )
                    matches.append(match)
                    matchNumber += 1
                }

                // Link previous round to this minor round
                let prevRoundMatches = matches.filter { $0.roundNumber == losersRound - 1 && $0.bracketType == .losers }
                for (i, prevMatch) in prevRoundMatches.enumerated() {
                    if let idx = matches.firstIndex(where: { $0.id == prevMatch.id }) {
                        let nextMatchIndex = matches.count - minorRoundMatches + (i / 2)
                        if nextMatchIndex < matches.count {
                            matches[idx].nextMatchId = matches[nextMatchIndex].id
                            matches[idx].nextMatchSlot = i % 2 == 0 ? .player1 : .player2
                        }
                    }
                }

                losersRound += 1
                currentMatches = minorRoundMatches
            }

            // Major round: losers bracket survivor + winner bracket drop-in
            let majorRoundMatches = currentMatches
            for _ in 0..<majorRoundMatches {
                let match = TournamentMatch(
                    roundNumber: losersRound,
                    matchNumber: matchNumber,
                    bracketType: .losers
                )
                matches.append(match)
                matchNumber += 1
            }

            // Link minor round to major round
            if losersRound > 2 {
                let minorMatches = matches.filter { $0.roundNumber == losersRound - 1 && $0.bracketType == .losers }
                for (i, prevMatch) in minorMatches.enumerated() {
                    if let idx = matches.firstIndex(where: { $0.id == prevMatch.id }) {
                        let nextMatchIndex = matches.count - majorRoundMatches + i
                        if nextMatchIndex < matches.count {
                            matches[idx].nextMatchId = matches[nextMatchIndex].id
                            matches[idx].nextMatchSlot = .player1  // Survivor takes P1
                        }
                    }
                }
            }

            losersRound += 1
            currentMatches = majorRoundMatches / 2
            if currentMatches == 0 { currentMatches = 1 }
        }

        return matches
    }

    // MARK: - Linking

    /// Links winners bracket losers to appropriate losers bracket matches.
    private static func linkWinnersToLosers(
        winnersBracket: inout [TournamentMatch],
        losersBracket: inout [TournamentMatch]
    ) {
        // Round 1 winners losers go to LR1
        let round1Winners = winnersBracket.filter { $0.roundNumber == 1 }
        let lr1Matches = losersBracket.filter { $0.roundNumber == 1 }

        for (i, winnersMatch) in round1Winners.enumerated() {
            let lr1Index = i / 2
            if lr1Index < lr1Matches.count {
                if let matchIndex = winnersBracket.firstIndex(where: { $0.id == winnersMatch.id }) {
                    winnersBracket[matchIndex].loserNextMatchId = lr1Matches[lr1Index].id
                    winnersBracket[matchIndex].loserNextMatchSlot = i % 2 == 0 ? .player1 : .player2
                }
            }
        }

        // Subsequent winners rounds drop into major rounds of losers bracket
        var losersRound = 2  // First drop-in round
        for winnersRound in 2...winnersBracket.map({ $0.roundNumber }).max()! {
            let winnersRoundMatches = winnersBracket.filter { $0.roundNumber == winnersRound }
            let losersRoundMatches = losersBracket.filter { $0.roundNumber == losersRound }

            for (i, winnersMatch) in winnersRoundMatches.enumerated() {
                if i < losersRoundMatches.count {
                    if let matchIndex = winnersBracket.firstIndex(where: { $0.id == winnersMatch.id }) {
                        winnersBracket[matchIndex].loserNextMatchId = losersRoundMatches[i].id
                        winnersBracket[matchIndex].loserNextMatchSlot = .player2  // Drop-in takes P2
                    }
                }
            }

            losersRound += 2  // Skip minor round, go to next major round
        }
    }

    // MARK: - Helpers

    private static func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }
}

// MARK: - Tournament Extension

extension Tournament {

    /// Handles a double elimination match result.
    mutating func handleDoubleEliminationResult(matchId: UUID) {
        guard let idx = matchIndex(byId: matchId) else { return }
        let match = matches[idx]

        // Advance winner
        if let nextId = match.nextMatchId,
           let nextIdx = matchIndex(byId: nextId),
           let winner = match.winner {
            if match.nextMatchSlot == .player1 {
                matches[nextIdx].player1Name = winner
            } else {
                matches[nextIdx].player2Name = winner
            }
        }

        // Handle loser (drop to losers bracket if from winners)
        if match.bracketType == .winners,
           let loserNextId = match.loserNextMatchId,
           let loserNextIdx = matchIndex(byId: loserNextId),
           let loser = match.loser {
            if match.loserNextMatchSlot == .player1 {
                matches[loserNextIdx].player1Name = loser
            } else {
                matches[loserNextIdx].player2Name = loser
            }
        }

        // Handle grand final result
        if match.isGrandFinal && !match.isGrandFinalReset {
            // If winners bracket player won, tournament is over
            // If losers bracket player won, need reset match
            if let winner = match.winner,
               let resetIndex = matches.firstIndex(where: { $0.isGrandFinalReset }) {
                // Check if loser bracket player won
                // They were player2 (came from losers), winners bracket was player1
                if winner == match.player2Name {
                    // Losers bracket player won - need reset
                    matches[resetIndex].player1Name = match.player1Name
                    matches[resetIndex].player2Name = match.player2Name
                } else {
                    // Winners bracket player won - no reset needed, mark reset as complete
                    matches[resetIndex].status = .complete
                    matches[resetIndex].winner = winner
                }
            }
        }

        // Check if tournament is complete
        if let grandFinalReset = matches.first(where: { $0.isGrandFinalReset }),
           grandFinalReset.status == .complete {
            status = .complete
        }
    }
}
