//
// Tournament.swift
// bitchat
//
// Tournament data model supporting multiple formats.
// Part of BeyScore Tournament System.
//

import Foundation

/// The status of a tournament.
enum TournamentStatus: String, Codable {
    case notStarted = "notStarted"
    case inProgress = "inProgress"
    case complete = "complete"

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .complete: return "Complete"
        }
    }
}

/// A tournament supporting multiple formats.
struct Tournament: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let roomCode: String
    var generation: BeybladeGeneration
    var matchType: MatchType
    var bestOf: BestOf
    var ownFinishEnabled: Bool
    var players: [String]
    var matches: [TournamentMatch]
    var status: TournamentStatus
    let createdAt: Date

    // Tournament format
    var tournamentType: TournamentType
    var stageConfig: TournamentStageConfig
    var currentStage: TournamentStage

    // Group Round Robin: player assignments
    var group1Players: [String]
    var group2Players: [String]

    // Swiss: standings and current round
    var swissStandings: [SwissStanding]
    var currentSwissRound: Int

    // Round Robin: standings
    var roundRobinStandings: [RoundRobinStanding]

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        roomCode: String,
        generation: BeybladeGeneration = .x,
        matchType: MatchType = .points4,
        bestOf: BestOf = .none,
        ownFinishEnabled: Bool = false,
        players: [String] = [],
        tournamentType: TournamentType = .singleElimination,
        stageConfig: TournamentStageConfig = TournamentStageConfig(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.roomCode = roomCode
        self.generation = generation
        self.matchType = matchType
        self.bestOf = bestOf
        self.ownFinishEnabled = ownFinishEnabled && generation.supportsOwnFinish
        self.players = players
        self.matches = []
        self.status = .notStarted
        self.createdAt = createdAt
        self.tournamentType = tournamentType
        self.stageConfig = stageConfig
        self.currentStage = .main
        self.group1Players = []
        self.group2Players = []
        self.swissStandings = []
        self.currentSwissRound = 1
        self.roundRobinStandings = []
    }

    // MARK: - Computed Properties

    /// Number of rounds in the tournament (format-aware).
    var numberOfRounds: Int {
        guard players.count > 1 else { return 0 }

        switch tournamentType {
        case .singleElimination:
            return Int(ceil(log2(Double(players.count))))
        case .doubleElimination:
            // Winners bracket rounds + losers bracket rounds + grand final(s)
            let winnerRounds = Int(ceil(log2(Double(players.count))))
            return winnerRounds * 2 + 1
        case .swiss:
            return SwissGenerator.numberOfRounds(for: players.count)
        case .roundRobin:
            // n-1 rounds for n players (or n for odd)
            return players.count % 2 == 0 ? players.count - 1 : players.count
        case .groupRoundRobin:
            let groupSize = players.count / 2
            return groupSize % 2 == 0 ? groupSize - 1 : groupSize
        }
    }

    /// Total Swiss rounds (Challonge formula).
    var totalSwissRounds: Int {
        SwissGenerator.numberOfRounds(for: players.count)
    }

    /// Whether the tournament is in the finals stage (multi-stage).
    var isInFinals: Bool {
        currentStage == .finals
    }

    /// Whether all group matches are complete (for Group RR).
    var areGroupsComplete: Bool {
        guard tournamentType == .groupRoundRobin else { return false }
        let group1Matches = matches.filter { $0.stage == .group1 }
        let group2Matches = matches.filter { $0.stage == .group2 }
        return group1Matches.allSatisfy { $0.status == .complete } &&
               group2Matches.allSatisfy { $0.status == .complete }
    }

    /// Whether the current Swiss round is complete.
    var isCurrentSwissRoundComplete: Bool {
        guard tournamentType == .swiss else { return false }
        let roundMatches = matches.filter { $0.roundNumber == currentSwissRound }
        return !roundMatches.isEmpty && roundMatches.allSatisfy { $0.status == .complete }
    }

    /// Total number of matches.
    var totalMatches: Int {
        return matches.count
    }

    /// Number of completed matches.
    var completedMatches: Int {
        return matches.filter { $0.status == .complete }.count
    }

    /// Number of pending matches.
    var pendingMatches: Int {
        return matches.filter { $0.status == .pending }.count
    }

    /// The current round being played.
    var currentRound: Int {
        for round in 1...numberOfRounds {
            let roundMatches = matches.filter { $0.roundNumber == round }
            if roundMatches.contains(where: { $0.status != .complete }) {
                return round
            }
        }
        return numberOfRounds
    }

    /// The tournament winner, if complete.
    var winner: String? {
        guard status == .complete else { return nil }
        return matches.first(where: { $0.roundNumber == numberOfRounds })?.winner
    }

    /// Matches in a specific round.
    func matches(inRound round: Int) -> [TournamentMatch] {
        return matches.filter { $0.roundNumber == round }.sorted { $0.matchNumber < $1.matchNumber }
    }

    /// Gets a match by ID.
    func match(byId id: UUID) -> TournamentMatch? {
        return matches.first { $0.id == id }
    }

    /// Gets the index of a match by ID.
    func matchIndex(byId id: UUID) -> Int? {
        return matches.firstIndex { $0.id == id }
    }

    // MARK: - Match Configuration

    /// Creates a MatchConfiguration for scoring.
    /// Uses finals-specific settings for finals stage matches if configured.
    func createMatchConfiguration(for match: TournamentMatch) -> MatchConfiguration {
        // Determine if this is a finals match
        let isFinalsMatch = match.stage == .finals

        // Use finals-specific settings if available, otherwise use tournament defaults
        let effectiveMatchType = (isFinalsMatch && stageConfig.finalsMatchType != nil)
            ? stageConfig.finalsMatchType!
            : matchType
        let effectiveBestOf = (isFinalsMatch && stageConfig.finalsBestOf != nil)
            ? stageConfig.finalsBestOf!
            : bestOf

        return MatchConfiguration(
            generation: generation,              // Always shared
            matchType: effectiveMatchType,       // Stage-specific
            bestOf: effectiveBestOf,             // Stage-specific
            ownFinishEnabled: ownFinishEnabled,  // Always shared
            player1Name: match.player1Name ?? "TBD",
            player2Name: match.player2Name ?? "TBD"
        )
    }
}

// MARK: - Tournament Extension for Bracket Updates

extension Tournament {

    /// Updates a match result and advances based on tournament type.
    mutating func updateMatchResult(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        history: [HistoryEntry]
    ) {
        guard let index = matchIndex(byId: matchId) else { return }

        var match = matches[index]
        match.player1Score = player1Score
        match.player2Score = player2Score
        match.player1SetWins = player1SetWins
        match.player2SetWins = player2SetWins
        match.winner = winner
        match.status = .complete
        match.matchHistory = history

        matches[index] = match

        // Handle format-specific progression
        switch tournamentType {
        case .singleElimination:
            advanceSingleElimination(match: match)

        case .doubleElimination:
            handleDoubleEliminationResult(matchId: matchId)

        case .swiss:
            updateSwissStandingsAfterMatch(match)
            // Check if round is complete and generate next
            if isCurrentSwissRoundComplete {
                if currentSwissRound < totalSwissRounds {
                    advanceSwissRound()
                } else if stageConfig.isMultiStage {
                    advanceToMultiStageFinals()
                } else {
                    checkSwissComplete()
                }
            }

        case .roundRobin:
            updateRoundRobinStandingsAfterMatch(match)
            // Check if all matches complete
            if matches.allSatisfy({ $0.status == .complete }) {
                if stageConfig.isMultiStage {
                    advanceToMultiStageFinals()
                } else {
                    status = .complete
                }
            }

        case .groupRoundRobin:
            updateRoundRobinStandingsAfterMatch(match)
            // Check if both groups complete
            if areGroupsComplete && currentStage != .finals {
                advanceToGroupFinals()
            } else if currentStage == .finals {
                // Handle finals progression like single/double elim
                if stageConfig.finalsType == .doubleElimination {
                    handleDoubleEliminationResult(matchId: matchId)
                } else {
                    advanceSingleElimination(match: matches[index])
                }
            }
        }

        // Update tournament status
        if status == .notStarted {
            status = .inProgress
        }
        checkTournamentComplete()
    }

    // MARK: - Single Elimination Advancement

    private mutating func advanceSingleElimination(match: TournamentMatch) {
        guard let winner = match.winner else { return }

        if let nextId = match.nextMatchId,
           let nextIndex = matchIndex(byId: nextId) {
            if match.nextMatchSlot == .player1 {
                matches[nextIndex].player1Name = winner
            } else {
                matches[nextIndex].player2Name = winner
            }
        }
    }

    // MARK: - Multi-Stage Finals

    private mutating func advanceToMultiStageFinals() {
        guard stageConfig.isMultiStage else { return }
        guard currentStage != .finals else { return }

        currentStage = .finals

        // Get top players based on format
        let qualifiers: [String]
        switch tournamentType {
        case .swiss:
            qualifiers = SwissGenerator.getTopPlayers(
                standings: swissStandings,
                count: stageConfig.finalsSize
            )
        case .roundRobin:
            qualifiers = RoundRobinGenerator.getTopPlayers(
                standings: roundRobinStandings,
                count: stageConfig.finalsSize
            )
        default:
            return
        }

        // Generate finals bracket
        var finalsMatches: [TournamentMatch]
        if stageConfig.finalsType == .doubleElimination {
            finalsMatches = DoubleEliminationGenerator.generateBracket(players: qualifiers)
        } else {
            finalsMatches = BracketGenerator.generateBracket(players: qualifiers)
        }

        // Mark all as finals stage
        for i in 0..<finalsMatches.count {
            finalsMatches[i].stage = .finals
        }

        matches.append(contentsOf: finalsMatches)
    }

    // MARK: - Swiss Completion

    private mutating func checkSwissComplete() {
        if currentSwissRound >= totalSwissRounds {
            if !stageConfig.isMultiStage {
                status = .complete
            }
        }
    }

    // MARK: - Tournament Completion

    private mutating func checkTournamentComplete() {
        switch tournamentType {
        case .singleElimination:
            let finalMatch = matches.first { $0.roundNumber == numberOfRounds }
            if finalMatch?.status == .complete {
                status = .complete
            }

        case .doubleElimination:
            // Check grand final reset
            if let reset = matches.first(where: { $0.isGrandFinalReset }),
               reset.status == .complete {
                status = .complete
            } else if let grandFinal = matches.first(where: { $0.isGrandFinal && !$0.isGrandFinalReset }),
                      grandFinal.status == .complete,
                      grandFinal.winner == grandFinal.player1Name {
                // Winners bracket player won, no reset needed
                if let resetIndex = matches.firstIndex(where: { $0.isGrandFinalReset }) {
                    matches[resetIndex].status = .complete
                    matches[resetIndex].winner = grandFinal.winner
                }
                status = .complete
            }

        case .swiss:
            if !stageConfig.isMultiStage && currentSwissRound >= totalSwissRounds && isCurrentSwissRoundComplete {
                status = .complete
            } else if stageConfig.isMultiStage && currentStage == .finals {
                checkFinalsComplete()
            }

        case .roundRobin:
            if matches.allSatisfy({ $0.status == .complete }) {
                if stageConfig.isMultiStage {
                    checkFinalsComplete()
                } else {
                    status = .complete
                }
            }

        case .groupRoundRobin:
            if currentStage == .finals {
                checkFinalsComplete()
            }
        }
    }

    private mutating func checkFinalsComplete() {
        let finalsMatches = matches.filter { $0.stage == .finals }
        if finalsMatches.allSatisfy({ $0.status == .complete }) {
            status = .complete
        }
    }

    /// Assigns a match to a device.
    mutating func assignMatch(matchId: UUID, to deviceId: String) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].assignedDeviceId = deviceId
        matches[index].status = .assigned

        if status == .notStarted {
            status = .inProgress
        }
    }

    /// Marks a match as in progress.
    mutating func startMatch(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].status = .inProgress
    }

    /// Marks a match as awaiting approval.
    mutating func submitScore(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].status = .awaitingApproval
    }

    /// Unassigns a match from a device.
    mutating func unassignMatch(matchId: UUID) {
        guard let index = matchIndex(byId: matchId) else { return }
        matches[index].assignedDeviceId = nil
        matches[index].status = .pending
    }
}
