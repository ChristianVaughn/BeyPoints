//
// RoundRobinGenerator.swift
// bitchat
//
// Round Robin tournament scheduling.
// Part of BeyScore Tournament System.
//

import Foundation

/// Generates Round Robin tournament schedules.
enum RoundRobinGenerator {

    // MARK: - Match Generation

    /// Total matches in a round robin = n(n-1)/2
    static func totalMatches(for playerCount: Int) -> Int {
        return playerCount * (playerCount - 1) / 2
    }

    /// Number of rounds in a round robin.
    /// Even players: n-1 rounds
    /// Odd players: n rounds (each player gets one bye)
    static func numberOfRounds(for playerCount: Int) -> Int {
        return playerCount % 2 == 0 ? playerCount - 1 : playerCount
    }

    /// Generates all matches for a round robin tournament.
    /// Uses the circle method for optimal scheduling.
    static func generateMatches(
        players: [String],
        stage: TournamentStage = .main
    ) -> [TournamentMatch] {
        guard players.count >= 2 else { return [] }

        var matches: [TournamentMatch] = []

        // Add dummy player for odd number of players
        var playersList = players
        if players.count % 2 == 1 {
            playersList.append("BYE")
        }

        let n = playersList.count
        let rounds = n - 1
        var globalMatchNumber = 0

        // Circle method: fix first player, rotate the rest
        for round in 0..<rounds {
            for i in 0..<(n / 2) {
                let p1Index = i
                let p2Index = n - 1 - i

                let p1 = playersList[p1Index]
                let p2 = playersList[p2Index]

                // Skip matches with the BYE player
                if p1 == "BYE" || p2 == "BYE" {
                    continue
                }

                var match = TournamentMatch(
                    roundNumber: round + 1,
                    matchNumber: globalMatchNumber,
                    player1Name: p1,
                    player2Name: p2,
                    stage: stage
                )
                matches.append(match)
                globalMatchNumber += 1
            }

            // Rotate players (keep first player fixed for circle method)
            let last = playersList.removeLast()
            playersList.insert(last, at: 1)
        }

        return matches
    }

    // MARK: - Standings

    /// Creates initial standings for all players.
    static func createInitialStandings(players: [String]) -> [RoundRobinStanding] {
        return players.map { RoundRobinStanding(playerName: $0) }
    }

    /// Updates standings after a match is completed.
    static func updateStandings(
        standings: inout [RoundRobinStanding],
        match: TournamentMatch
    ) {
        guard let winner = match.winner,
              let p1Name = match.player1Name,
              let p2Name = match.player2Name else { return }

        guard let p1Index = standings.firstIndex(where: { $0.playerName == p1Name }),
              let p2Index = standings.firstIndex(where: { $0.playerName == p2Name }) else {
            return
        }

        // Update wins/losses
        if winner == p1Name {
            standings[p1Index].wins += 1
            standings[p2Index].losses += 1
        } else {
            standings[p2Index].wins += 1
            standings[p1Index].losses += 1
        }

        // Update points for/against
        standings[p1Index].pointsFor += match.player1Score
        standings[p1Index].pointsAgainst += match.player2Score
        standings[p2Index].pointsFor += match.player2Score
        standings[p2Index].pointsAgainst += match.player1Score
    }

    // MARK: - Finals Qualification

    /// Gets top N players from standings for finals.
    static func getTopPlayers(standings: [RoundRobinStanding], count: Int) -> [String] {
        let sorted = standings.sorted {
            // Primary: wins
            if $0.wins != $1.wins {
                return $0.wins > $1.wins
            }
            // Secondary: point differential
            return $0.pointDifferential > $1.pointDifferential
        }
        return Array(sorted.prefix(count).map { $0.playerName })
    }
}

// MARK: - Group Round Robin Generator

/// Generates Group Round Robin tournaments (2 groups).
enum GroupRoundRobinGenerator {

    /// Generates a Group Round Robin tournament.
    static func generateTournament(
        players: [String],
        shuffle: Bool = true
    ) -> (matches: [TournamentMatch], group1Players: [String], group2Players: [String]) {

        // Shuffle and split into 2 equal groups
        let playerList = shuffle ? players.shuffled() : players
        let midpoint = playerList.count / 2
        let group1Players = Array(playerList[0..<midpoint])
        let group2Players = Array(playerList[midpoint...])

        // Generate RR for each group
        var group1Matches = RoundRobinGenerator.generateMatches(
            players: group1Players,
            stage: .group1
        )
        let group2Matches = RoundRobinGenerator.generateMatches(
            players: group2Players,
            stage: .group2
        )

        // Combine all matches
        let allMatches = group1Matches + group2Matches

        return (allMatches, group1Players, Array(group2Players))
    }

    /// Generates finals bracket from group standings.
    static func generateFinals(
        group1Standings: [RoundRobinStanding],
        group2Standings: [RoundRobinStanding],
        finalsSize: Int,
        finalsType: TournamentType
    ) -> [TournamentMatch] {
        // Get qualifiers from each group
        let perGroup = finalsSize / 2
        let group1Qualifiers = RoundRobinGenerator.getTopPlayers(
            standings: group1Standings,
            count: perGroup
        )
        let group2Qualifiers = RoundRobinGenerator.getTopPlayers(
            standings: group2Standings,
            count: perGroup
        )

        // Interleave for seeding: 1st G1, 1st G2, 2nd G1, 2nd G2, etc.
        var finalsPlayers: [String] = []
        for i in 0..<perGroup {
            if i < group1Qualifiers.count {
                finalsPlayers.append(group1Qualifiers[i])
            }
            if i < group2Qualifiers.count {
                finalsPlayers.append(group2Qualifiers[i])
            }
        }

        // Generate finals bracket based on type
        var finalsMatches: [TournamentMatch]
        if finalsType == .doubleElimination {
            finalsMatches = DoubleEliminationGenerator.generateBracket(players: finalsPlayers)
        } else {
            finalsMatches = BracketGenerator.generateBracket(players: finalsPlayers)
        }

        // Mark all matches as finals stage
        for i in 0..<finalsMatches.count {
            finalsMatches[i].stage = .finals
        }

        return finalsMatches
    }
}

// MARK: - Tournament Extension

extension Tournament {

    /// Initializes Round Robin standings for the tournament.
    mutating func initializeRoundRobinStandings() {
        if tournamentType == .groupRoundRobin {
            // Use group-specific standings
            roundRobinStandings = RoundRobinGenerator.createInitialStandings(
                players: group1Players + group2Players
            )
        } else {
            roundRobinStandings = RoundRobinGenerator.createInitialStandings(players: players)
        }
    }

    /// Gets standings for a specific group.
    func groupStandings(for stage: TournamentStage) -> [RoundRobinStanding] {
        let groupPlayers: [String]
        switch stage {
        case .group1: groupPlayers = group1Players
        case .group2: groupPlayers = group2Players
        default: return roundRobinStandings
        }
        return roundRobinStandings.filter { groupPlayers.contains($0.playerName) }
    }

    /// Updates Round Robin standings after a match completes.
    mutating func updateRoundRobinStandingsAfterMatch(_ match: TournamentMatch) {
        RoundRobinGenerator.updateStandings(standings: &roundRobinStandings, match: match)
    }

    /// Advances Group Round Robin to finals if groups are complete.
    mutating func advanceToGroupFinals() {
        guard areGroupsComplete else { return }
        guard currentStage != .finals else { return }

        currentStage = .finals

        let group1Standings = groupStandings(for: .group1)
        let group2Standings = groupStandings(for: .group2)

        let finalsMatches = GroupRoundRobinGenerator.generateFinals(
            group1Standings: group1Standings,
            group2Standings: group2Standings,
            finalsSize: stageConfig.finalsSize,
            finalsType: stageConfig.finalsType
        )

        matches.append(contentsOf: finalsMatches)
    }
}
