//
// ChallongeSyncManager.swift
// bitchat
//
// Manages Challonge synchronization for tournaments.
// Handles import, periodic refresh, and conflict detection.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Manages Challonge synchronization for tournaments
@MainActor
final class ChallongeSyncManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ChallongeSyncManager()

    // MARK: - Published State

    @Published private(set) var syncState: ChallongeSyncState?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: ChallongeError?
    @Published private(set) var conflicts: [MatchConflict] = []
    @Published private(set) var newMatchCount = 0

    // MARK: - Configuration

    /// Minimum refresh interval (5 minutes) to conserve API calls
    static let minimumRefreshInterval: TimeInterval = 300

    /// Default to manual refresh (no auto-polling)
    var autoRefreshEnabled = false
    var refreshInterval: TimeInterval = 300  // 5 minutes

    private var refreshTimer: Timer?
    private let challongeService = ChallongeService.shared
    private let tournamentManager = TournamentManager.shared

    // MARK: - Persistence

    private let syncStateKey = "beyscore.challongeSyncState"

    // MARK: - Initialization

    private init() {
        loadSyncState()
    }

    // MARK: - Import Flow

    /// Fetches tournament preview without creating local tournament
    func fetchPreview(from urlOrId: String) async throws -> ChallongeImportPreview {
        isSyncing = true
        lastError = nil

        defer { isSyncing = false }

        let tournamentId = ChallongeService.parseTournamentId(from: urlOrId)
        let challongeTournament = try await challongeService.fetchTournament(id: tournamentId)

        return ChallongeImportPreview(from: challongeTournament, url: urlOrId)
    }

    /// Imports a tournament from Challonge and creates local Tournament
    /// - Parameters:
    ///   - urlOrId: Challonge tournament URL or ID
    ///   - isMultiStage: Whether this is a multi-stage tournament
    ///   - primaryFormat: Single-stage format or preliminary stage format
    ///   - finalsFormat: Finals stage format (for multi-stage only)
    ///   - generation: Beyblade generation for all matches
    ///   - matchType: Match type for preliminary/all matches
    ///   - bestOf: Best-of setting for preliminary/all matches
    ///   - ownFinishEnabled: Own finish setting for preliminary/all matches
    ///   - finalsSettings: Optional separate match settings for finals stage (matchType, bestOf, ownFinish)
    /// - Returns: Created local Tournament
    func importTournament(
        from urlOrId: String,
        isMultiStage: Bool,
        primaryFormat: TournamentType,
        finalsFormat: TournamentType?,
        generation: BeybladeGeneration,
        matchType: MatchType,
        bestOf: BestOf,
        ownFinishEnabled: Bool,
        finalsSettings: (MatchType, BestOf, Bool)?
    ) async throws -> Tournament {
        isSyncing = true
        lastError = nil

        defer { isSyncing = false }

        // Parse URL to extract tournament ID
        let tournamentId = ChallongeService.parseTournamentId(from: urlOrId)

        // Fetch from Challonge
        let challongeTournament = try await challongeService.fetchTournament(id: tournamentId)

        // Create local tournament with user-selected format
        var tournament = createLocalTournament(
            from: challongeTournament,
            isMultiStage: isMultiStage,
            primaryFormat: primaryFormat,
            finalsFormat: finalsFormat,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            finalsSettings: finalsSettings
        )

        // Create sync state with user-selected formats
        var newSyncState = ChallongeSyncState(
            challongeId: challongeTournament.id,
            challongeUrl: urlOrId,
            isMultiStage: isMultiStage,
            primaryFormat: primaryFormat,
            finalsFormat: finalsFormat,
            hasGroupStages: challongeTournament.groupStagesEnabled ?? false,
            swissRoundCount: challongeTournament.swissRounds
        )

        // Record API call
        newSyncState.recordApiCall()

        // Map participants
        if let participants = challongeTournament.participants {
            newSyncState.participantMappings = participants.map { wrapper in
                ChallongeParticipantMapping(
                    playerName: wrapper.participant.displayName,
                    challongeParticipantId: wrapper.participant.id,
                    challongeSeed: wrapper.participant.seed,
                    groupPlayerIds: wrapper.participant.groupPlayerIds ?? []
                )
            }
        }

        // Create participant lookup (ID -> name) including group stage IDs
        let participantLookup = createParticipantLookup(from: newSyncState.participantMappings)

        // Map matches using user-selected formats
        if let challongeMatches = challongeTournament.matches {
            let localMatches = createLocalMatches(
                from: challongeMatches.map(\.match),
                participantLookup: participantLookup,
                isMultiStage: isMultiStage,
                primaryFormat: primaryFormat,
                finalsFormat: finalsFormat
            )
            tournament.matches = localMatches

            // Create match mappings
            newSyncState.matchMappings = zip(localMatches, challongeMatches).map { local, wrapper in
                ChallongeMatchMapping(
                    localMatchId: local.id,
                    challongeMatchId: wrapper.match.id
                )
            }

            newSyncState.lastKnownRound = challongeMatches.map { $0.match.round }.max() ?? 0
        }

        newSyncState.challongeState = challongeTournament.state
        syncState = newSyncState
        saveSyncState()

        // Calculate standings from imported completed matches (for Swiss/RR preliminary stages)
        if isMultiStage && (primaryFormat == .swiss || primaryFormat == .roundRobin) {
            let prelimMatches = tournament.matches.filter { $0.stage == .group1 }
            tournament.swissStandings = calculateStandingsFromImportedMatches(
                matches: prelimMatches,
                players: tournament.players
            )
            if primaryFormat == .roundRobin {
                tournament.roundRobinStandings = calculateRoundRobinStandings(
                    matches: prelimMatches,
                    players: tournament.players
                )
            }
        } else if primaryFormat == .swiss {
            tournament.swissStandings = calculateStandingsFromImportedMatches(
                matches: tournament.matches,
                players: tournament.players
            )
        } else if primaryFormat == .roundRobin {
            tournament.roundRobinStandings = calculateRoundRobinStandings(
                matches: tournament.matches,
                players: tournament.players
            )
        }

        return tournament
    }

    // MARK: - Standings Calculation

    /// Calculates Swiss/Round Robin standings from completed match data
    private func calculateStandingsFromImportedMatches(
        matches: [TournamentMatch],
        players: [String]
    ) -> [SwissStanding] {
        var standings: [String: SwissStanding] = [:]

        // Initialize all players
        for player in players {
            standings[player] = SwissStanding(playerName: player)
        }

        // Process completed matches
        for match in matches where match.status == .complete {
            guard let winner = match.winner,
                  let player1 = match.player1Name,
                  let player2 = match.player2Name else { continue }

            let loser = winner == player1 ? player2 : player1

            // Update wins/losses
            standings[winner]?.wins += 1
            standings[loser]?.losses += 1

            // Track opponents for Buchholz calculation
            standings[player1]?.opponentsPlayed.append(player2)
            standings[player2]?.opponentsPlayed.append(player1)
        }

        // Calculate Buchholz scores (sum of opponents' points)
        var result = Array(standings.values)
        for i in result.indices {
            let opponentPoints = result[i].opponentsPlayed.compactMap { opponentName in
                standings[opponentName]?.points
            }.reduce(0.0, +)
            result[i].buchholzScore = opponentPoints
        }

        // Sort by points (descending), then by Buchholz (descending)
        result.sort { a, b in
            if a.points != b.points {
                return a.points > b.points
            }
            return a.buchholzScore > b.buchholzScore
        }

        return result
    }

    /// Calculates Round Robin standings from completed match data
    private func calculateRoundRobinStandings(
        matches: [TournamentMatch],
        players: [String]
    ) -> [RoundRobinStanding] {
        var standings: [String: RoundRobinStanding] = [:]

        // Initialize all players
        for player in players {
            standings[player] = RoundRobinStanding(playerName: player)
        }

        // Process completed matches
        for match in matches where match.status == .complete {
            guard let winner = match.winner,
                  let player1 = match.player1Name,
                  let player2 = match.player2Name else { continue }

            let loser = winner == player1 ? player2 : player1

            // Update wins/losses
            standings[winner]?.wins += 1
            standings[loser]?.losses += 1

            // Update points for/against
            standings[player1]?.pointsFor += match.player1Score
            standings[player1]?.pointsAgainst += match.player2Score
            standings[player2]?.pointsFor += match.player2Score
            standings[player2]?.pointsAgainst += match.player1Score
        }

        // Sort by wins (descending), then by point differential (descending)
        var result = Array(standings.values)
        result.sort { a, b in
            if a.wins != b.wins {
                return a.wins > b.wins
            }
            return a.pointDifferential > b.pointDifferential
        }

        return result
    }

    // MARK: - Refresh/Sync

    /// Performs a sync with Challonge, detecting new matches and conflicts
    func refresh() async throws {
        guard var currentSyncState = syncState else {
            throw ChallongeError.notAuthenticated
        }

        isSyncing = true
        lastError = nil

        defer { isSyncing = false }

        // Fetch current state from Challonge
        let challongeTournament = try await challongeService.fetchTournament(
            id: String(currentSyncState.challongeId)
        )

        // Record API call
        currentSyncState.recordApiCall()

        guard let tournament = tournamentManager.currentTournament else {
            syncState = currentSyncState
            saveSyncState()
            return
        }

        // Create participant lookup
        let participantLookup = createParticipantLookup(from: currentSyncState.participantMappings)

        // Check for new matches (Swiss/RR round generation)
        if let challongeMatches = challongeTournament.matches {
            let newMatches = detectNewMatches(
                challongeMatches: challongeMatches.map(\.match),
                existingMappings: currentSyncState.matchMappings
            )

            if !newMatches.isEmpty {
                newMatchCount = newMatches.count
                currentSyncState.syncStatus = .newMatchesAvailable

                // Auto-import new matches
                importNewMatches(
                    newMatches,
                    participantLookup: participantLookup,
                    into: &currentSyncState
                )
            }

            // Detect conflicts
            let detectedConflicts = detectConflicts(
                challongeMatches: challongeMatches.map(\.match),
                localTournament: tournament,
                participantLookup: participantLookup,
                mappings: currentSyncState.matchMappings
            )

            conflicts = detectedConflicts

            if !detectedConflicts.isEmpty {
                currentSyncState.syncStatus = .hasConflicts
            } else if newMatchCount == 0 {
                currentSyncState.syncStatus = .synced
            }

            currentSyncState.lastKnownRound = challongeMatches.map { $0.match.round }.max() ?? currentSyncState.lastKnownRound
        }

        currentSyncState.lastSyncedAt = Date()
        currentSyncState.challongeState = challongeTournament.state
        syncState = currentSyncState
        saveSyncState()
    }

    /// Starts periodic refresh (if enabled)
    func startPeriodicRefresh() {
        guard autoRefreshEnabled else { return }

        stopPeriodicRefresh()

        let interval = max(refreshInterval, Self.minimumRefreshInterval)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                do {
                    try await self?.refresh()
                } catch {
                    self?.lastError = error as? ChallongeError
                }
            }
        }
    }

    /// Stops periodic refresh
    func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Conflict Resolution

    /// Resolves a conflict by keeping local data (user will manually update Challonge)
    func resolveConflict(_ conflict: MatchConflict, resolution: ConflictResolution) {
        guard var currentSyncState = syncState else { return }
        guard let index = conflicts.firstIndex(where: { $0.matchId == conflict.matchId }) else { return }

        var resolved = conflicts[index]
        resolved.resolved = true
        resolved.resolution = resolution
        conflicts[index] = resolved

        // Update mapping
        if let mappingIndex = currentSyncState.matchMappings.firstIndex(where: { $0.localMatchId == conflict.matchId }) {
            currentSyncState.matchMappings[mappingIndex].hasConflict = false
            currentSyncState.matchMappings[mappingIndex].conflictDetails = resolved
        }

        // Check if all conflicts resolved
        if conflicts.allSatisfy({ $0.resolved }) {
            currentSyncState.syncStatus = .synced
        }

        syncState = currentSyncState
        saveSyncState()
    }

    // MARK: - Tournament Creation

    private func createLocalTournament(
        from challonge: ChallongeTournament,
        isMultiStage: Bool,
        primaryFormat: TournamentType,
        finalsFormat: TournamentType?,
        generation: BeybladeGeneration,
        matchType: MatchType,
        bestOf: BestOf,
        ownFinishEnabled: Bool,
        finalsSettings: (MatchType, BestOf, Bool)?
    ) -> Tournament {
        // Extract player names from participants
        let players = challonge.participants?.map { $0.participant.displayName } ?? []

        // Use user-selected format instead of unreliable auto-detection
        // For multi-stage tournaments, use the preliminary format as the main tournament type
        let tournamentFormat = primaryFormat

        // Configure multi-stage settings
        var stageConfig = TournamentStageConfig()
        if isMultiStage, let finals = finalsFormat {
            stageConfig.isMultiStage = true
            stageConfig.stage1Type = primaryFormat
            stageConfig.finalsType = finals
            // Set finals-specific match settings if different from preliminary
            if let (finalsMatchType, finalsBestOf, _) = finalsSettings {
                stageConfig.finalsMatchType = finalsMatchType
                stageConfig.finalsBestOf = finalsBestOf
            }
        }

        var tournament = Tournament(
            name: challonge.name,
            roomCode: RoomCode.generate().code,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled && generation.supportsOwnFinish,
            players: players,
            tournamentType: tournamentFormat,
            stageConfig: stageConfig
        )

        // Set appropriate status
        switch challonge.state {
        case "pending":
            tournament.status = .notStarted
        case "underway":
            tournament.status = .inProgress
        case "complete", "awaiting_review":
            tournament.status = .complete
        default:
            tournament.status = .notStarted
        }

        return tournament
    }

    private func createLocalMatches(
        from challongeMatches: [ChallongeMatch],
        participantLookup: [Int: String],
        isMultiStage: Bool,
        primaryFormat: TournamentType,
        finalsFormat: TournamentType?
    ) -> [TournamentMatch] {
        return challongeMatches.enumerated().map { index, cm in
            var match = TournamentMatch(
                roundNumber: cm.absoluteRound,
                matchNumber: cm.suggestedPlayOrder ?? index,
                player1Name: cm.player1Id.flatMap { participantLookup[$0] },
                player2Name: cm.player2Id.flatMap { participantLookup[$0] }
            )

            // Determine which format applies to this match based on group_id
            let matchFormat: TournamentType
            if isMultiStage {
                // Use group_id to determine stage (reliable detection)
                if cm.isGroupStage {
                    matchFormat = primaryFormat  // Preliminary stage
                    match.stage = .group1  // Use group1 for all preliminary matches
                } else {
                    matchFormat = finalsFormat ?? primaryFormat  // Finals stage
                    match.stage = .finals  // Finals bracket matches
                }
            } else {
                matchFormat = primaryFormat
                match.stage = .main  // Single-stage tournaments use main
            }

            // Set bracket type for double elimination
            if matchFormat == .doubleElimination && cm.isLosersBracket {
                match.bracketType = .losers
            }

            // Set match status and scores
            if cm.isComplete {
                match.status = .complete
                if let winnerId = cm.winnerId {
                    match.winner = participantLookup[winnerId]
                }
                let scores = cm.parsedScores
                match.player1Score = scores.player1
                match.player2Score = scores.player2
                match.player1SetWins = scores.player1Sets
                match.player2SetWins = scores.player2Sets
            } else if cm.isOpen {
                match.status = .pending
            } else {
                match.status = .pending
            }

            return match
        }
    }

    // MARK: - Participant Mapping

    private func createParticipantLookup(from mappings: [ChallongeParticipantMapping]) -> [Int: String] {
        var lookup: [Int: String] = [:]
        for mapping in mappings {
            // Map main participant ID
            lookup[mapping.challongeParticipantId] = mapping.playerName
            // Map group stage IDs
            for groupId in mapping.groupPlayerIds {
                lookup[groupId] = mapping.playerName
            }
        }
        return lookup
    }

    // MARK: - New Match Detection

    private func detectNewMatches(
        challongeMatches: [ChallongeMatch],
        existingMappings: [ChallongeMatchMapping]
    ) -> [ChallongeMatch] {
        let mappedIds = Set(existingMappings.map(\.challongeMatchId))
        return challongeMatches.filter { !mappedIds.contains($0.id) }
    }

    private func importNewMatches(
        _ newMatches: [ChallongeMatch],
        participantLookup: [Int: String],
        into syncState: inout ChallongeSyncState
    ) {
        guard var updatedTournament = tournamentManager.currentTournament else { return }

        for cm in newMatches {
            let match = TournamentMatch(
                roundNumber: cm.absoluteRound,
                matchNumber: cm.suggestedPlayOrder ?? updatedTournament.matches.count,
                player1Name: cm.player1Id.flatMap { participantLookup[$0] },
                player2Name: cm.player2Id.flatMap { participantLookup[$0] },
                stage: cm.isGroupStage ? .group1 : .main
            )

            updatedTournament.matches.append(match)

            // Add to mappings
            let mapping = ChallongeMatchMapping(
                localMatchId: match.id,
                challongeMatchId: cm.id
            )
            syncState.matchMappings.append(mapping)
        }

        // Update Swiss round if applicable
        if updatedTournament.tournamentType == .swiss {
            let maxRound = newMatches.map { $0.absoluteRound }.max() ?? 0
            if maxRound > updatedTournament.currentSwissRound {
                updatedTournament.currentSwissRound = maxRound
            }
        }

        tournamentManager.setTournament(updatedTournament)
    }

    // MARK: - Conflict Detection

    private func detectConflicts(
        challongeMatches: [ChallongeMatch],
        localTournament: Tournament,
        participantLookup: [Int: String],
        mappings: [ChallongeMatchMapping]
    ) -> [MatchConflict] {
        var detectedConflicts: [MatchConflict] = []

        for mapping in mappings {
            guard let challongeMatch = challongeMatches.first(where: { $0.id == mapping.challongeMatchId }),
                  let localMatch = localTournament.match(byId: mapping.localMatchId) else {
                continue
            }

            // Only check completed matches for winner mismatch
            if localMatch.status == .complete && challongeMatch.isComplete {
                let challongeWinner = challongeMatch.winnerId.flatMap { participantLookup[$0] }
                if let localWinner = localMatch.winner,
                   let remoteWinner = challongeWinner,
                   localWinner != remoteWinner {
                    detectedConflicts.append(MatchConflict(
                        matchId: localMatch.id,
                        conflictType: .winnerMismatch,
                        localValue: localWinner,
                        challongeValue: remoteWinner
                    ))
                }
            }

            // Check for state mismatch (complete locally but not on Challonge, or vice versa)
            let localComplete = localMatch.status == .complete
            let challongeComplete = challongeMatch.isComplete
            if localComplete != challongeComplete {
                detectedConflicts.append(MatchConflict(
                    matchId: localMatch.id,
                    conflictType: .stateMismatch,
                    localValue: localComplete ? "Complete" : "In Progress",
                    challongeValue: challongeComplete ? "Complete" : "In Progress"
                ))
            }
        }

        return detectedConflicts
    }

    // MARK: - Persistence

    private func saveSyncState() {
        guard let state = syncState else {
            UserDefaults.standard.removeObject(forKey: syncStateKey)
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: syncStateKey)
        }
    }

    private func loadSyncState() {
        guard let data = UserDefaults.standard.data(forKey: syncStateKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        syncState = try? decoder.decode(ChallongeSyncState.self, from: data)
    }

    // MARK: - Cleanup

    /// Clears sync state (disconnects from Challonge)
    func clearSyncState() {
        stopPeriodicRefresh()
        syncState = nil
        conflicts = []
        newMatchCount = 0
        lastError = nil
        UserDefaults.standard.removeObject(forKey: syncStateKey)
    }

    /// Whether currently linked to a Challonge tournament
    var isLinked: Bool {
        syncState != nil
    }

    /// API calls remaining this month
    var remainingApiCalls: Int {
        syncState?.remainingCalls ?? 500
    }

    /// Whether approaching API limit
    var isApproachingLimit: Bool {
        syncState?.isApproachingLimit ?? false
    }
}
