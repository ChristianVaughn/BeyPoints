//
// ScoringEnums.swift
// bitchat
//
// Core enums for the Beyblade scoring system.
// Based on the reference web scoreboard app.
// Part of BeyScore Tournament System.
//

import Foundation
import SwiftUI

// MARK: - Beyblade Generation

/// The Beyblade generation/series being played.
/// Each generation has different available win conditions and point values.
enum BeybladeGeneration: String, Codable, CaseIterable, Identifiable {
    case x = "x"
    case burst = "burst"
    case metalFight = "mfb-zero-g"  // Metal Fight / Zero-G
    case plastics = "plastics-hms"  // Plastics / HMS

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .x: return "X"
        case .burst: return "Burst"
        case .metalFight: return "Metal Fight / Zero-G"
        case .plastics: return "Plastics / HMS"
        }
    }

    var shortName: String {
        switch self {
        case .x: return "X"
        case .burst: return "Burst"
        case .metalFight: return "MFB"
        case .plastics: return "Plastics"
        }
    }

    /// Available win conditions for this generation.
    var availableConditions: [WinCondition] {
        switch self {
        case .x:
            return [.xtreme, .burst, .over, .spin]
        case .burst:
            return [.burst, .over, .spin]
        case .metalFight, .plastics:
            return [.over, .spin]
        }
    }

    /// Whether Own Finish is available for this generation.
    var supportsOwnFinish: Bool {
        return self == .x
    }

    /// Default match type for this generation.
    var defaultMatchType: MatchType {
        switch self {
        case .x: return .points4
        default: return .points3
        }
    }
}

// MARK: - Match Type

/// The point target for winning a match (single game).
enum MatchType: String, Codable, CaseIterable, Identifiable {
    case points3 = "3pts"
    case points4 = "4pts"
    case points5 = "5pts"
    case points7 = "7pts"
    case noLimit = "nolimit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .points3: return "First to 3"
        case .points4: return "First to 4"
        case .points5: return "First to 5"
        case .points7: return "First to 7"
        case .noLimit: return "No Limit"
        }
    }

    var shortName: String {
        switch self {
        case .points3: return "3 pts"
        case .points4: return "4 pts"
        case .points5: return "5 pts"
        case .points7: return "7 pts"
        case .noLimit: return "∞"
        }
    }

    /// Target points to win, nil for no limit.
    var maxPoints: Int? {
        switch self {
        case .points3: return 3
        case .points4: return 4
        case .points5: return 5
        case .points7: return 7
        case .noLimit: return nil
        }
    }

    /// Available match types for a generation.
    static func availableTypes(for generation: BeybladeGeneration) -> [MatchType] {
        switch generation {
        case .x:
            return [.points4, .points5, .points7, .noLimit]
        default:
            return [.points3, .points4, .points5, .noLimit]
        }
    }
}

// MARK: - Best Of

/// The best-of format for a match series.
enum BestOf: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case bestOf3 = "bo3"
    case bestOf5 = "bo5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Single Game"
        case .bestOf3: return "Best of 3"
        case .bestOf5: return "Best of 5"
        }
    }

    var shortName: String {
        switch self {
        case .none: return "-"
        case .bestOf3: return "Bo3"
        case .bestOf5: return "Bo5"
        }
    }

    /// Number of wins needed to win the match.
    var winsRequired: Int? {
        switch self {
        case .none: return nil
        case .bestOf3: return 2
        case .bestOf5: return 3
        }
    }

    /// Maximum number of games in this format.
    var maxGames: Int {
        switch self {
        case .none: return 1
        case .bestOf3: return 3
        case .bestOf5: return 5
        }
    }
}

// MARK: - Win Condition

/// The condition that awarded points in a round.
enum WinCondition: String, Codable, CaseIterable, Identifiable {
    case xtreme = "xtreme"   // X generation only, 3 points
    case burst = "burst"     // X and Burst, 2 points
    case over = "over"       // All generations, 2 points (1 in Metal/Plastics)
    case spin = "spin"       // All generations, 1 point
    case penalty = "penalty" // All generations, 1 point to opponent
    case ownFinish = "own"   // X generation only, 1 point to opponent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .xtreme: return "Xtreme"
        case .burst: return "Burst"
        case .over: return "Over"
        case .spin: return "Spin Finish"
        case .penalty: return "Penalty"
        case .ownFinish: return "Own Finish"
        }
    }

    /// Short label for chip display.
    var chipLabel: String {
        switch self {
        case .xtreme: return "XTR"
        case .burst: return "BST"
        case .over: return "OVR"
        case .spin: return "SPF"
        case .penalty: return "PEN"
        case .ownFinish: return "OWN"
        }
    }

    /// Color for chip display.
    var chipColor: Color {
        switch self {
        case .xtreme: return .purple
        case .burst: return .red
        case .over: return .blue
        case .spin: return .yellow
        case .penalty: return .red
        case .ownFinish: return .orange
        }
    }

    /// Points awarded for this condition.
    func points(for generation: BeybladeGeneration) -> Int {
        switch self {
        case .xtreme:
            return 3  // X only
        case .burst:
            return 2  // X and Burst
        case .over:
            switch generation {
            case .x, .burst:
                return 2
            case .metalFight, .plastics:
                return 1
            }
        case .spin:
            return 1
        case .penalty:
            return 1  // To opponent
        case .ownFinish:
            return 1  // To opponent
        }
    }

    /// Whether this condition gives points to the opponent instead.
    var awardsToOpponent: Bool {
        switch self {
        case .penalty, .ownFinish:
            return true
        default:
            return false
        }
    }
}

// MARK: - Match Status

/// The status of a tournament match.
enum MatchStatus: String, Codable {
    case pending = "pending"           // Not yet started
    case assigned = "assigned"         // Assigned to a scoreboard
    case inProgress = "inProgress"     // Being played
    case awaitingApproval = "awaiting" // Score submitted, waiting for master approval
    case complete = "complete"         // Finished and approved

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .awaitingApproval: return "Awaiting Approval"
        case .complete: return "Complete"
        }
    }
}

// MARK: - Player Identifier

/// Identifies which player in a match.
enum Player: String, Codable {
    case player1 = "p1"
    case player2 = "p2"

    var displayName: String {
        switch self {
        case .player1: return "Player 1"
        case .player2: return "Player 2"
        }
    }

    /// The other player.
    var opponent: Player {
        switch self {
        case .player1: return .player2
        case .player2: return .player1
        }
    }
}
