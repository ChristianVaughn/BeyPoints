//
// ChallongeSyncModels.swift
// bitchat
//
// Models for tracking Challonge sync state, ID mappings, and conflicts.
// Part of BeyScore Tournament System.
//

import Foundation

// MARK: - Sync State

/// Tracks Challonge sync state for a tournament
struct ChallongeSyncState: Codable, Equatable {
    let challongeId: Int
    let challongeUrl: String
    var lastSyncedAt: Date
    var syncStatus: ChallongeSyncStatus
    var matchMappings: [ChallongeMatchMapping]
    var participantMappings: [ChallongeParticipantMapping]

    // User-selected format configuration
    var isMultiStage: Bool
    var primaryFormat: TournamentType      // Single-stage format or preliminary format
    var finalsFormat: TournamentType?      // Only set for multi-stage tournaments

    var challongeState: String
    var hasGroupStages: Bool               // From API - hint only
    var swissRoundCount: Int?              // From API - unreliable
    var lastKnownRound: Int
    var apiCallsThisMonth: Int
    var apiCallsResetDate: Date

    init(
        challongeId: Int,
        challongeUrl: String,
        isMultiStage: Bool,
        primaryFormat: TournamentType,
        finalsFormat: TournamentType? = nil,
        hasGroupStages: Bool = false,
        swissRoundCount: Int? = nil
    ) {
        self.challongeId = challongeId
        self.challongeUrl = challongeUrl
        self.lastSyncedAt = Date()
        self.syncStatus = .synced
        self.matchMappings = []
        self.participantMappings = []
        self.isMultiStage = isMultiStage
        self.primaryFormat = primaryFormat
        self.finalsFormat = finalsFormat
        self.challongeState = "pending"
        self.hasGroupStages = hasGroupStages
        self.swissRoundCount = swissRoundCount
        self.lastKnownRound = 0
        self.apiCallsThisMonth = 0
        self.apiCallsResetDate = ChallongeSyncState.startOfCurrentMonth()
    }

    /// Gets the start of the current month for API call tracking
    private static func startOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }

    /// Increments API call counter, resetting if month changed
    mutating func recordApiCall() {
        let currentMonthStart = ChallongeSyncState.startOfCurrentMonth()
        if apiCallsResetDate < currentMonthStart {
            apiCallsThisMonth = 0
            apiCallsResetDate = currentMonthStart
        }
        apiCallsThisMonth += 1
    }

    /// Whether we're approaching the rate limit (warning at 400)
    var isApproachingLimit: Bool {
        apiCallsThisMonth >= 400
    }

    /// Remaining API calls this month
    var remainingCalls: Int {
        max(0, 500 - apiCallsThisMonth)
    }
}

// MARK: - Sync Status

/// Current sync status with Challonge
enum ChallongeSyncStatus: String, Codable {
    case synced = "synced"
    case hasConflicts = "hasConflicts"
    case newMatchesAvailable = "newMatchesAvailable"
    case syncError = "syncError"
    case neverSynced = "neverSynced"

    var displayName: String {
        switch self {
        case .synced: return "Synced"
        case .hasConflicts: return "Conflicts Detected"
        case .newMatchesAvailable: return "New Matches"
        case .syncError: return "Sync Error"
        case .neverSynced: return "Not Synced"
        }
    }

    var iconName: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .hasConflicts: return "exclamationmark.triangle.fill"
        case .newMatchesAvailable: return "plus.circle.fill"
        case .syncError: return "xmark.circle.fill"
        case .neverSynced: return "questionmark.circle"
        }
    }
}

// MARK: - Match Mapping

/// Maps local match UUID to Challonge match ID
struct ChallongeMatchMapping: Codable, Equatable, Identifiable {
    var id: UUID { localMatchId }
    let localMatchId: UUID
    let challongeMatchId: Int
    var lastChallongeState: String
    var lastLocalStatus: String
    var hasConflict: Bool
    var conflictDetails: MatchConflict?
    var lastSyncedAt: Date

    init(localMatchId: UUID, challongeMatchId: Int) {
        self.localMatchId = localMatchId
        self.challongeMatchId = challongeMatchId
        self.lastChallongeState = "pending"
        self.lastLocalStatus = "pending"
        self.hasConflict = false
        self.conflictDetails = nil
        self.lastSyncedAt = Date()
    }
}

// MARK: - Participant Mapping

/// Maps local player name to Challonge participant ID
struct ChallongeParticipantMapping: Codable, Equatable, Identifiable {
    var id: Int { challongeParticipantId }
    let playerName: String
    let challongeParticipantId: Int
    let challongeSeed: Int?
    let groupPlayerIds: [Int]

    init(
        playerName: String,
        challongeParticipantId: Int,
        challongeSeed: Int? = nil,
        groupPlayerIds: [Int] = []
    ) {
        self.playerName = playerName
        self.challongeParticipantId = challongeParticipantId
        self.challongeSeed = challongeSeed
        self.groupPlayerIds = groupPlayerIds
    }

    /// All Challonge IDs that map to this player (main + group stage IDs)
    var allChallongeIds: [Int] {
        [challongeParticipantId] + groupPlayerIds
    }
}

// MARK: - Conflict

/// Describes a conflict between local and Challonge data
struct MatchConflict: Codable, Equatable, Identifiable {
    var id: UUID { matchId }
    let matchId: UUID
    let conflictType: ConflictType
    let localValue: String
    let challongeValue: String
    let detectedAt: Date
    var resolved: Bool
    var resolution: ConflictResolution?

    init(
        matchId: UUID,
        conflictType: ConflictType,
        localValue: String,
        challongeValue: String
    ) {
        self.matchId = matchId
        self.conflictType = conflictType
        self.localValue = localValue
        self.challongeValue = challongeValue
        self.detectedAt = Date()
        self.resolved = false
        self.resolution = nil
    }
}

/// Type of data conflict
enum ConflictType: String, Codable {
    case winnerMismatch = "winnerMismatch"
    case scoreMismatch = "scoreMismatch"
    case stateMismatch = "stateMismatch"
    case playerMismatch = "playerMismatch"

    var displayName: String {
        switch self {
        case .winnerMismatch: return "Winner Mismatch"
        case .scoreMismatch: return "Score Mismatch"
        case .stateMismatch: return "Status Mismatch"
        case .playerMismatch: return "Player Mismatch"
        }
    }

    var iconName: String {
        switch self {
        case .winnerMismatch: return "trophy"
        case .scoreMismatch: return "number"
        case .stateMismatch: return "arrow.triangle.2.circlepath"
        case .playerMismatch: return "person.2"
        }
    }
}

/// How a conflict was resolved
enum ConflictResolution: String, Codable {
    case keepLocal = "keepLocal"
    case acceptChallonge = "acceptChallonge"
    case ignored = "ignored"

    var displayName: String {
        switch self {
        case .keepLocal: return "Kept Local"
        case .acceptChallonge: return "Accepted Challonge"
        case .ignored: return "Ignored"
        }
    }
}

// MARK: - Import Preview

/// Preview data shown before confirming import
/// Note: Format is not included because Challonge API fields are unreliable for detection.
/// User must select the format manually in the import flow.
struct ChallongeImportPreview {
    let name: String
    let playerCount: Int
    let matchCount: Int
    let status: String
    let hasGroupStages: Bool  // Hint only - user must confirm
    let swissRounds: Int?     // Unreliable - kept for reference only
    let challongeUrl: String

    init(from tournament: ChallongeTournament, url: String) {
        self.name = tournament.name
        self.playerCount = tournament.participantsCount ?? tournament.participants?.count ?? 0
        self.matchCount = tournament.matches?.count ?? 0
        self.status = tournament.state.capitalized
        self.hasGroupStages = tournament.groupStagesEnabled ?? false
        self.swissRounds = tournament.swissRounds
        self.challongeUrl = url
    }
}
