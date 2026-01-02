//
// BracketGenerator.swift
// bitchat
//
// Generates single-elimination tournament brackets with bye handling.
// Part of BeyScore Tournament System.
//

import Foundation

/// Generates single-elimination tournament brackets.
enum BracketGenerator {

    /// Generates a complete bracket for the given players.
    /// - Parameters:
    ///   - players: Array of player names
    ///   - shuffle: Whether to shuffle players before seeding (default: false)
    /// - Returns: Array of matches forming the bracket
    static func generateBracket(players: [String], shuffle: Bool = false) -> [TournamentMatch] {
        guard players.count >= 2 else { return [] }

        let playerList = shuffle ? players.shuffled() : players

        // Calculate bracket size (next power of 2)
        let bracketSize = nextPowerOf2(playerList.count)
        let numberOfRounds = Int(log2(Double(bracketSize)))
        let numberOfByes = bracketSize - playerList.count

        // Seed players with byes distributed evenly
        let seededPlayers = seedPlayers(playerList, bracketSize: bracketSize, byes: numberOfByes)

        // Generate all matches
        var allMatches: [TournamentMatch] = []

        // Create matches for each round
        for round in 1...numberOfRounds {
            let matchesInRound = bracketSize / Int(pow(2.0, Double(round)))
            var roundMatches: [TournamentMatch] = []

            for matchNum in 0..<matchesInRound {
                let match = TournamentMatch(
                    roundNumber: round,
                    matchNumber: matchNum
                )
                roundMatches.append(match)
            }

            allMatches.append(contentsOf: roundMatches)
        }

        // Link matches to next round
        allMatches = linkMatches(allMatches, numberOfRounds: numberOfRounds, bracketSize: bracketSize)

        // Assign players to first round
        allMatches = assignPlayersToFirstRound(allMatches, players: seededPlayers, bracketSize: bracketSize)

        // Process byes (auto-advance players with byes)
        allMatches = processByes(allMatches)

        return allMatches
    }

    // MARK: - Helper Functions

    /// Returns the next power of 2 >= n.
    private static func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    /// Seeds players with byes distributed to give top seeds the byes.
    private static func seedPlayers(_ players: [String], bracketSize: Int, byes: Int) -> [String?] {
        var seeded: [String?] = Array(repeating: nil, count: bracketSize)

        // Standard bracket seeding order for power-of-2 brackets
        let seedOrder = generateSeedOrder(bracketSize)

        // Place players according to seed order
        for (index, player) in players.enumerated() {
            if index < seedOrder.count {
                seeded[seedOrder[index]] = player
            }
        }

        return seeded
    }

    /// Generates the seed order for a bracket (e.g., [0, 7, 3, 4, 1, 6, 2, 5] for 8 players).
    /// This ensures 1 vs 8, 4 vs 5, etc. matchups in round 1.
    private static func generateSeedOrder(_ size: Int) -> [Int] {
        if size == 2 {
            return [0, 1]
        }

        var order: [Int] = []
        func recurse(positions: [Int]) {
            if positions.count == 2 {
                order.append(contentsOf: positions)
            } else {
                let half = positions.count / 2
                var first: [Int] = []
                var second: [Int] = []

                for i in 0..<half {
                    first.append(positions[i])
                    second.append(positions[positions.count - 1 - i])
                }

                recurse(positions: first)
                recurse(positions: second)
            }
        }

        recurse(positions: Array(0..<size))
        return order
    }

    /// Links matches to their next-round matches.
    private static func linkMatches(_ matches: [TournamentMatch], numberOfRounds: Int, bracketSize: Int) -> [TournamentMatch] {
        var linked = matches

        for i in 0..<linked.count {
            let match = linked[i]

            // Find next match in bracket
            if match.roundNumber < numberOfRounds {
                let nextRoundMatches = linked.filter { $0.roundNumber == match.roundNumber + 1 }
                let nextMatchNumber = match.matchNumber / 2

                if let nextMatch = nextRoundMatches.first(where: { $0.matchNumber == nextMatchNumber }) {
                    linked[i].nextMatchId = nextMatch.id
                    linked[i].nextMatchSlot = match.matchNumber % 2 == 0 ? .player1 : .player2
                }
            }
        }

        return linked
    }

    /// Assigns players to first round matches.
    private static func assignPlayersToFirstRound(_ matches: [TournamentMatch], players: [String?], bracketSize: Int) -> [TournamentMatch] {
        var assigned = matches
        let firstRoundMatches = assigned.enumerated().filter { $0.element.roundNumber == 1 }

        for (index, _) in firstRoundMatches {
            let matchNum = assigned[index].matchNumber
            let p1Index = matchNum * 2
            let p2Index = matchNum * 2 + 1

            if p1Index < players.count {
                assigned[index].player1Name = players[p1Index]
            }
            if p2Index < players.count {
                assigned[index].player2Name = players[p2Index]
            }
        }

        return assigned
    }

    /// Processes bye matches - auto-advances the single player.
    private static func processByes(_ matches: [TournamentMatch]) -> [TournamentMatch] {
        var processed = matches

        // Find first round matches with byes
        for i in 0..<processed.count {
            if processed[i].roundNumber == 1 && processed[i].isBye {
                // Auto-advance the non-nil player
                let winner = processed[i].player1Name ?? processed[i].player2Name
                processed[i].winner = winner
                processed[i].status = .complete

                // Advance to next match
                if let nextId = processed[i].nextMatchId,
                   let nextIndex = processed.firstIndex(where: { $0.id == nextId }) {
                    if processed[i].nextMatchSlot == .player1 {
                        processed[nextIndex].player1Name = winner
                    } else {
                        processed[nextIndex].player2Name = winner
                    }
                }
            }
        }

        return processed
    }
}

// MARK: - Tournament Extension

extension Tournament {

    /// Generates the bracket for this tournament based on tournament type.
    mutating func generateBracket(shuffle: Bool = false) {
        guard status == .notStarted else { return }
        guard players.count >= 2 else { return }

        switch tournamentType {
        case .singleElimination:
            matches = BracketGenerator.generateBracket(players: players, shuffle: shuffle)

        case .doubleElimination:
            matches = DoubleEliminationGenerator.generateBracket(players: players, shuffle: shuffle)

        case .swiss:
            // Initialize standings
            initializeSwissStandings()
            // Generate first round
            matches = SwissGenerator.generateFirstRound(players: players, shuffle: shuffle)

        case .roundRobin:
            // Generate all matches
            matches = RoundRobinGenerator.generateMatches(players: players)
            // Initialize standings
            initializeRoundRobinStandings()

        case .groupRoundRobin:
            // Generate groups and matches
            let result = GroupRoundRobinGenerator.generateTournament(
                players: players,
                shuffle: shuffle
            )
            matches = result.matches
            group1Players = result.group1Players
            group2Players = result.group2Players
            // Initialize standings
            initializeRoundRobinStandings()
        }
    }

    /// Creates a new tournament with generated bracket.
    static func create(
        name: String,
        roomCode: String,
        players: [String],
        generation: BeybladeGeneration = .x,
        matchType: MatchType = .points4,
        bestOf: BestOf = .none,
        ownFinishEnabled: Bool = false,
        tournamentType: TournamentType = .singleElimination,
        stageConfig: TournamentStageConfig = TournamentStageConfig(),
        shuffle: Bool = false
    ) -> Tournament {
        var tournament = Tournament(
            name: name,
            roomCode: roomCode,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            players: players,
            tournamentType: tournamentType,
            stageConfig: stageConfig
        )
        tournament.generateBracket(shuffle: shuffle)
        return tournament
    }
}
