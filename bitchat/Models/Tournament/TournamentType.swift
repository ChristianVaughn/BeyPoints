//
// TournamentType.swift
// bitchat
//
// Tournament format types and multi-stage configuration.
// Part of BeyScore Tournament System.
//

import Foundation

/// Tournament format types.
enum TournamentType: String, Codable, CaseIterable {
    case singleElimination = "single"
    case doubleElimination = "double"
    case swiss = "swiss"
    case roundRobin = "roundRobin"
    case groupRoundRobin = "groupRR"

    var displayName: String {
        switch self {
        case .singleElimination: return "Single Elimination"
        case .doubleElimination: return "Double Elimination"
        case .swiss: return "Swiss"
        case .roundRobin: return "Round Robin"
        case .groupRoundRobin: return "Group Round Robin"
        }
    }

    var description: String {
        switch self {
        case .singleElimination: return "One loss and you're out"
        case .doubleElimination: return "Two losses and you're out"
        case .swiss: return "Fixed rounds, players paired by record"
        case .roundRobin: return "Everyone plays everyone once"
        case .groupRoundRobin: return "Two groups, top players advance to finals"
        }
    }

    /// Valid as finals stage in multi-stage tournament.
    var validForFinals: Bool {
        self == .singleElimination || self == .doubleElimination
    }

    /// Whether this format uses elimination-style brackets.
    var isEliminationFormat: Bool {
        self == .singleElimination || self == .doubleElimination
    }

    /// Whether this format requires dynamic round generation (Swiss).
    var requiresDynamicPairing: Bool {
        self == .swiss
    }
}

// MARK: - Multi-Stage Configuration

/// Configuration for multi-stage tournaments.
struct TournamentStageConfig: Codable, Equatable {
    var isMultiStage: Bool = false
    var stage1Type: TournamentType = .swiss
    var finalsType: TournamentType = .singleElimination
    var finalsSize: Int = 8  // 4, 8, 16, or 32

    // Finals-specific match settings (nil = use tournament default)
    var finalsMatchType: MatchType?
    var finalsBestOf: BestOf?

    /// Valid finals sizes for advancement.
    static let validFinalsSizes = [4, 8, 16, 32]

    /// Validates the configuration.
    var isValid: Bool {
        if !isMultiStage { return true }
        return finalsType.validForFinals && Self.validFinalsSizes.contains(finalsSize)
    }
}

// MARK: - Tournament Stage

/// Stage/group identifier for matches.
enum TournamentStage: String, Codable {
    case main = "main"           // For single-stage tournaments
    case group1 = "group1"       // Group Round Robin: Group A
    case group2 = "group2"       // Group Round Robin: Group B
    case finals = "finals"       // Finals stage in multi-stage

    var displayName: String {
        switch self {
        case .main: return "Main"
        case .group1: return "Group A"
        case .group2: return "Group B"
        case .finals: return "Finals"
        }
    }
}

// MARK: - Bracket Type (for Double Elimination)

/// Bracket type for double elimination tournaments.
enum BracketType: String, Codable {
    case winners = "winners"
    case losers = "losers"
    case grandFinal = "grandFinal"

    var displayName: String {
        switch self {
        case .winners: return "Winners Bracket"
        case .losers: return "Losers Bracket"
        case .grandFinal: return "Grand Finals"
        }
    }
}

// MARK: - Swiss Standing

/// Player standing in a Swiss tournament.
struct SwissStanding: Codable, Equatable, Identifiable {
    let id: UUID
    let playerName: String
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0
    var opponentsPlayed: [String] = []
    var buchholzScore: Double = 0  // Tiebreaker: sum of opponents' scores

    init(id: UUID = UUID(), playerName: String) {
        self.id = id
        self.playerName = playerName
    }

    /// Total points (1 for win, 0.5 for draw).
    var points: Double {
        Double(wins) + Double(draws) * 0.5
    }

    /// Games played.
    var gamesPlayed: Int {
        wins + losses + draws
    }

    /// Win rate percentage.
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed)
    }
}

// MARK: - Round Robin Standing

/// Player standing in a Round Robin tournament.
struct RoundRobinStanding: Codable, Equatable, Identifiable {
    let id: UUID
    let playerName: String
    var wins: Int = 0
    var losses: Int = 0
    var pointsFor: Int = 0      // Total points scored
    var pointsAgainst: Int = 0  // Total points conceded

    init(id: UUID = UUID(), playerName: String) {
        self.id = id
        self.playerName = playerName
    }

    /// Point differential (tiebreaker).
    var pointDifferential: Int {
        pointsFor - pointsAgainst
    }

    /// Games played.
    var gamesPlayed: Int {
        wins + losses
    }
}
