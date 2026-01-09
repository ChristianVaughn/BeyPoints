//
// ChallongeModels.swift
// bitchat
//
// Models for decoding Challonge v1 API responses.
// Part of BeyScore Tournament System.
//

import Foundation

// MARK: - API Response Wrappers

/// Challonge wraps objects in a key matching the type
struct ChallongeTournamentWrapper: Codable {
    let tournament: ChallongeTournament
}

struct ChallongeMatchWrapper: Codable {
    let match: ChallongeMatch
}

struct ChallongeParticipantWrapper: Codable {
    let participant: ChallongeParticipant
}

// MARK: - Tournament

/// Tournament data from Challonge API
struct ChallongeTournament: Codable {
    let id: Int
    let name: String
    let url: String
    let tournamentType: String
    let state: String
    let groupStagesEnabled: Bool?
    let swissRounds: Int?
    let participantsCount: Int?
    let startedAt: String?
    let completedAt: String?
    let progressMeter: Int?

    // Included when ?include_participants=1
    let participants: [ChallongeParticipantWrapper]?
    // Included when ?include_matches=1
    let matches: [ChallongeMatchWrapper]?

    enum CodingKeys: String, CodingKey {
        case id, name, url, state, participants, matches
        case tournamentType = "tournament_type"
        case groupStagesEnabled = "group_stages_enabled"
        case swissRounds = "swiss_rounds"
        case participantsCount = "participants_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case progressMeter = "progress_meter"
    }

    /// DEPRECATED: Auto-detection is unreliable. User should select format manually.
    ///
    /// This property is kept for reference only. The Challonge API fields are unreliable:
    /// - `tournament_type` only reflects the finals format, not preliminary stage
    /// - `swiss_rounds` contains incorrect values (e.g., shows 3 for 5-round Swiss)
    /// - Cannot distinguish Swiss vs Round Robin from API data alone
    ///
    /// Use user-selected formats instead via ChallongeImportView.
    @available(*, deprecated, message: "Use user-selected format instead. API detection is unreliable.")
    var detectedFormat: TournamentType {
        // Check for group stages first (Swiss → Top cut)
        if groupStagesEnabled == true {
            return .groupRoundRobin
        }

        switch tournamentType.lowercased() {
        case "single elimination":
            return .singleElimination
        case "double elimination":
            return .doubleElimination
        case "round robin":
            return .roundRobin
        case "swiss":
            return .swiss
        default:
            return .singleElimination
        }
    }

    /// Whether the tournament is complete on Challonge
    var isComplete: Bool {
        state == "complete" || state == "awaiting_review"
    }

    /// Whether the tournament is in progress
    var isInProgress: Bool {
        state == "underway"
    }
}

// MARK: - Match

/// Match data from Challonge API
struct ChallongeMatch: Codable {
    let id: Int
    let tournamentId: Int
    let identifier: String?
    let round: Int
    let state: String
    let player1Id: Int?
    let player2Id: Int?
    let winnerId: Int?
    let loserId: Int?
    let scoresCsv: String?
    let groupId: Int?
    let suggestedPlayOrder: Int?
    let player1PrereqMatchId: Int?
    let player2PrereqMatchId: Int?
    let player1IsPrereqMatchLoser: Bool?
    let player2IsPrereqMatchLoser: Bool?
    let prerequisiteMatchIdsCsv: String?
    let startedAt: String?
    let underwayAt: String?
    let updatedAt: String?
    let forfeited: Bool?

    enum CodingKeys: String, CodingKey {
        case id, round, state, identifier, forfeited
        case tournamentId = "tournament_id"
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case winnerId = "winner_id"
        case loserId = "loser_id"
        case scoresCsv = "scores_csv"
        case groupId = "group_id"
        case suggestedPlayOrder = "suggested_play_order"
        case player1PrereqMatchId = "player1_prereq_match_id"
        case player2PrereqMatchId = "player2_prereq_match_id"
        case player1IsPrereqMatchLoser = "player1_is_prereq_match_loser"
        case player2IsPrereqMatchLoser = "player2_is_prereq_match_loser"
        case prerequisiteMatchIdsCsv = "prerequisite_match_ids_csv"
        case startedAt = "started_at"
        case underwayAt = "underway_at"
        case updatedAt = "updated_at"
    }

    /// Whether this is a group/Swiss stage match (vs finals bracket)
    var isGroupStage: Bool {
        groupId != nil
    }

    /// Whether this is a losers bracket match (negative round in double elim)
    var isLosersBracket: Bool {
        round < 0
    }

    /// Absolute round number (handles negative for losers bracket)
    var absoluteRound: Int {
        abs(round)
    }

    /// Whether the match is complete
    var isComplete: Bool {
        state == "complete"
    }

    /// Whether the match is ready to play
    var isOpen: Bool {
        state == "open"
    }

    /// Parse scores from CSV format (e.g., "3-1" or "3-1,2-3,3-2" for sets)
    var parsedScores: (player1: Int, player2: Int, player1Sets: Int, player2Sets: Int) {
        guard let csv = scoresCsv, !csv.isEmpty else {
            return (0, 0, 0, 0)
        }

        let sets = csv.split(separator: ",")
        var p1Total = 0
        var p2Total = 0
        var p1Sets = 0
        var p2Sets = 0

        for set in sets {
            let scores = set.split(separator: "-")
            if scores.count == 2,
               let s1 = Int(scores[0].trimmingCharacters(in: .whitespaces)),
               let s2 = Int(scores[1].trimmingCharacters(in: .whitespaces)) {
                p1Total += s1
                p2Total += s2
                if s1 > s2 { p1Sets += 1 }
                else if s2 > s1 { p2Sets += 1 }
            }
        }

        // If only one set, use totals as scores
        if sets.count == 1 {
            return (p1Total, p2Total, 0, 0)
        }

        // Multiple sets - return set wins
        return (p1Total, p2Total, p1Sets, p2Sets)
    }
}

// MARK: - Participant

/// Participant data from Challonge API
struct ChallongeParticipant: Codable {
    let id: Int
    let tournamentId: Int
    let name: String
    let seed: Int?
    let active: Bool?
    let groupId: Int?
    let finalRank: Int?
    let groupPlayerIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, name, seed, active
        case tournamentId = "tournament_id"
        case groupId = "group_id"
        case finalRank = "final_rank"
        case groupPlayerIds = "group_player_ids"
    }

    /// Display name (cleaned up)
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Credentials

/// Challonge API credentials
struct ChallongeCredentials: Codable, Equatable {
    let username: String
    let apiKey: String

    /// Creates HTTP Basic auth header value
    var basicAuthHeader: String {
        let credentials = "\(username):\(apiKey)"
        let data = credentials.data(using: .utf8)!
        return "Basic \(data.base64EncodedString())"
    }

    /// Whether credentials appear valid (non-empty)
    var isValid: Bool {
        !username.isEmpty && !apiKey.isEmpty
    }
}

// MARK: - API Errors

/// Errors from Challonge API operations
enum ChallongeError: Error, LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case invalidResponse
    case tournamentNotFound
    case rateLimited
    case networkError(Error)
    case apiError(statusCode: Int, message: String?)
    case invalidTournamentUrl
    case decodingError(Error)
    case matchMappingNotFound(matchId: UUID)
    case participantMappingNotFound(playerName: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Challonge credentials not configured"
        case .invalidCredentials:
            return "Invalid Challonge username or API key"
        case .invalidResponse:
            return "Invalid response from Challonge"
        case .tournamentNotFound:
            return "Tournament not found on Challonge"
        case .rateLimited:
            return "Challonge API limit reached (450/500 calls). Features disabled until next month."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return message ?? "Challonge API error (code: \(code))"
        case .invalidTournamentUrl:
            return "Invalid Challonge tournament URL"
        case .decodingError(let error):
            return "Failed to parse Challonge response: \(error.localizedDescription)"
        case .matchMappingNotFound(let matchId):
            return "Match not linked to Challonge (ID: \(matchId.uuidString.prefix(8))...)"
        case .participantMappingNotFound(let playerName):
            return "Player '\(playerName)' not found in Challonge tournament"
        }
    }
}

// MARK: - Match State Filter

/// Filter for fetching matches by state
enum ChallongeMatchState: String {
    case all = "all"
    case pending = "pending"
    case open = "open"
    case complete = "complete"
}
