//
// SwissGenerator.swift
// bitchat
//
// Swiss tournament pairing and round generation.
// Part of BeyScore Tournament System.
//

import Foundation

/// Generates Swiss tournament pairings.
enum SwissGenerator {

    // MARK: - Round Calculation

    /// Number of rounds for Swiss format (Challonge formula).
    /// For 16 players = 4 rounds.
    static func numberOfRounds(for playerCount: Int) -> Int {
        guard playerCount > 1 else { return 0 }
        return Int(ceil(log2(Double(playerCount))))
    }

    // MARK: - Initial Setup

    /// Creates initial standings for all players.
    static func createInitialStandings(players: [String]) -> [SwissStanding] {
        return players.map { SwissStanding(playerName: $0) }
    }

    /// Generates the first round pairings (random or seeded).
    static func generateFirstRound(players: [String], shuffle: Bool = true) -> [TournamentMatch] {
        let playerList = shuffle ? players.shuffled() : players
        var matches: [TournamentMatch] = []

        // Pair players: 1st vs 2nd, 3rd vs 4th, etc.
        for i in stride(from: 0, to: playerList.count - 1, by: 2) {
            let match = TournamentMatch(
                roundNumber: 1,
                matchNumber: matches.count,
                player1Name: playerList[i],
                player2Name: playerList[i + 1]
            )
            matches.append(match)
        }

        // Handle bye for odd number of players
        if playerList.count % 2 == 1 {
            var byeMatch = TournamentMatch(
                roundNumber: 1,
                matchNumber: matches.count,
                player1Name: playerList.last
            )
            byeMatch.winner = playerList.last
            byeMatch.status = .complete
            matches.append(byeMatch)
        }

        return matches
    }

    // MARK: - Round Generation

    /// Generate pairings for the next round based on current standings.
    static func generateRound(
        standings: [SwissStanding],
        roundNumber: Int
    ) -> [TournamentMatch] {
        // Sort by points (highest first), then by Buchholz tiebreaker
        let sorted = standings.sorted {
            if $0.points != $1.points {
                return $0.points > $1.points
            }
            return $0.buchholzScore > $1.buchholzScore
        }

        var matches: [TournamentMatch] = []
        var paired: Set<String> = []

        // Pair players using Swiss pairing rules
        for standing in sorted {
            // Skip if already paired
            if paired.contains(standing.playerName) { continue }

            // Find the best available opponent
            for opponent in sorted {
                // Can't play yourself
                if opponent.playerName == standing.playerName { continue }
                // Can't play someone already paired this round
                if paired.contains(opponent.playerName) { continue }
                // Can't play someone you've already played
                if standing.opponentsPlayed.contains(opponent.playerName) { continue }

                // Create the match
                let match = TournamentMatch(
                    roundNumber: roundNumber,
                    matchNumber: matches.count,
                    player1Name: standing.playerName,
                    player2Name: opponent.playerName
                )
                matches.append(match)
                paired.insert(standing.playerName)
                paired.insert(opponent.playerName)
                break
            }
        }

        // Handle odd player getting a bye
        if sorted.count % 2 == 1 {
            let byePlayer = sorted.first { !paired.contains($0.playerName) }
            if let player = byePlayer {
                // Check if player already had a bye
                let hadBye = !player.opponentsPlayed.contains("BYE") && player.opponentsPlayed.count < roundNumber - 1

                var byeMatch = TournamentMatch(
                    roundNumber: roundNumber,
                    matchNumber: matches.count,
                    player1Name: player.playerName
                )
                byeMatch.winner = player.playerName
                byeMatch.status = .complete
                matches.append(byeMatch)
            }
        }

        return matches
    }

    // MARK: - Standings Updates

    /// Updates standings after a match is completed.
    static func updateStandings(
        standings: inout [SwissStanding],
        match: TournamentMatch
    ) {
        guard let winner = match.winner else { return }

        // Find player indices
        guard let p1Index = standings.firstIndex(where: { $0.playerName == match.player1Name }),
              let p2Index = standings.firstIndex(where: { $0.playerName == match.player2Name }) else {
            // Handle bye case
            if let p1Index = standings.firstIndex(where: { $0.playerName == match.player1Name }),
               match.isBye {
                standings[p1Index].wins += 1
                standings[p1Index].opponentsPlayed.append("BYE")
            }
            return
        }

        // Update win/loss records
        if winner == match.player1Name {
            standings[p1Index].wins += 1
            standings[p2Index].losses += 1
        } else {
            standings[p2Index].wins += 1
            standings[p1Index].losses += 1
        }

        // Record that they played each other
        standings[p1Index].opponentsPlayed.append(match.player2Name!)
        standings[p2Index].opponentsPlayed.append(match.player1Name!)
    }

    /// Calculates Buchholz tiebreaker scores for all standings.
    /// Buchholz = sum of opponents' points.
    static func calculateBuchholz(standings: inout [SwissStanding]) {
        for i in 0..<standings.count {
            var buchholz: Double = 0
            for opponentName in standings[i].opponentsPlayed {
                if opponentName == "BYE" {
                    // Bye counts as playing average opponent
                    buchholz += Double(standings.count) / 2.0 * 0.5
                } else if let opponent = standings.first(where: { $0.playerName == opponentName }) {
                    buchholz += opponent.points
                }
            }
            standings[i].buchholzScore = buchholz
        }
    }

    // MARK: - Finals Qualification

    /// Gets top N players from standings for finals.
    static func getTopPlayers(standings: [SwissStanding], count: Int) -> [String] {
        let sorted = standings.sorted {
            if $0.points != $1.points {
                return $0.points > $1.points
            }
            return $0.buchholzScore > $1.buchholzScore
        }
        return Array(sorted.prefix(count).map { $0.playerName })
    }
}

// MARK: - Tournament Extension

extension Tournament {

    /// Initializes Swiss standings for the tournament.
    mutating func initializeSwissStandings() {
        swissStandings = SwissGenerator.createInitialStandings(players: players)
    }

    /// Updates Swiss standings after a match completes.
    mutating func updateSwissStandingsAfterMatch(_ match: TournamentMatch) {
        SwissGenerator.updateStandings(standings: &swissStandings, match: match)
        SwissGenerator.calculateBuchholz(standings: &swissStandings)
    }

    /// Generates the next Swiss round if current is complete.
    mutating func advanceSwissRound() {
        guard isCurrentSwissRoundComplete else { return }
        guard currentSwissRound < totalSwissRounds else { return }

        currentSwissRound += 1
        let newMatches = SwissGenerator.generateRound(
            standings: swissStandings,
            roundNumber: currentSwissRound
        )
        matches.append(contentsOf: newMatches)
    }
}
