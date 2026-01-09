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

    /// Delay before fetching new matches after score submission
    /// Gives Challonge time to process the score and generate new rounds
    static let postSubmitFetchDelay: TimeInterval = 5.0

    /// Default to manual refresh (no auto-polling)
    var autoRefreshEnabled = false
    var refreshInterval: TimeInterval = 300  // 5 minutes

    private var refreshTimer: Timer?
    private let challongeService = ChallongeService.shared
    private let tournamentManager = TournamentManager.shared

    // MARK: - Debug Logging

    #if DEBUG
    private static let isDebugLogging = true
    #else
    private static let isDebugLogging = false
    #endif

    private func debugLog(_ message: String) {
        if Self.isDebugLogging {
            print("[Challonge DEBUG] \(message)")
        }
    }

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

            // Create match mappings with player IDs
            newSyncState.matchMappings = zip(localMatches, challongeMatches).map { local, wrapper in
                ChallongeMatchMapping(
                    localMatchId: local.id,
                    challongeMatchId: wrapper.match.id,
                    challongePlayer1Id: wrapper.match.player1Id,
                    challongePlayer2Id: wrapper.match.player2Id
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

            // Add to mappings with player IDs
            let mapping = ChallongeMatchMapping(
                localMatchId: match.id,
                challongeMatchId: cm.id,
                challongePlayer1Id: cm.player1Id,
                challongePlayer2Id: cm.player2Id
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

    // MARK: - Score Submission to Challonge

    /// Submits an approved match score to Challonge
    /// - Parameters:
    ///   - matchId: Local match ID
    ///   - winner: Winner's name
    ///   - player1Score: Player 1's final score
    ///   - player2Score: Player 2's final score
    ///   - player1SetWins: Player 1's set wins (for Best Of matches)
    ///   - player2SetWins: Player 2's set wins (for Best Of matches)
    ///   - isBestOf: Whether this is a Best Of match
    func submitScoreToChallonge(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        isBestOf: Bool
    ) async throws {
        debugLog("submitScoreToChallonge called:")
        debugLog("  - matchId: \(matchId)")
        debugLog("  - winner: \(winner)")
        debugLog("  - scores: p1=\(player1Score), p2=\(player2Score)")
        debugLog("  - setWins: p1=\(player1SetWins), p2=\(player2SetWins)")
        debugLog("  - isBestOf: \(isBestOf)")

        guard var currentSyncState = syncState else {
            debugLog("FAILED: No sync state (not authenticated)")
            throw ChallongeError.notAuthenticated
        }

        // Find the Challonge match ID from our mappings
        guard let mapping = currentSyncState.matchMappings.first(where: { $0.localMatchId == matchId }) else {
            debugLog("FAILED: No match mapping found for local match \(matchId)")
            debugLog("  Available mappings: \(currentSyncState.matchMappings.map { "local=\($0.localMatchId) → challonge=\($0.challongeMatchId)" }.joined(separator: ", "))")
            throw ChallongeError.matchMappingNotFound(matchId: matchId)
        }
        debugLog("Match mapping: local=\(matchId) → challonge=\(mapping.challongeMatchId)")
        debugLog("  - challongePlayer1Id: \(mapping.challongePlayer1Id.map(String.init) ?? "nil")")
        debugLog("  - challongePlayer2Id: \(mapping.challongePlayer2Id.map(String.init) ?? "nil")")

        // Find the local match to determine which player won (player1 or player2)
        guard let localMatch = tournamentManager.currentTournament?.matches.first(where: { $0.id == matchId }) else {
            debugLog("FAILED: Local match not found for ID: \(matchId)")
            throw ChallongeError.matchMappingNotFound(matchId: matchId)
        }

        // Determine winner ID from the match mapping (not participant mapping)
        // This is critical for group/Swiss stages where player IDs differ from main participant IDs
        let winnerId: Int
        if localMatch.player1Name == winner {
            guard let p1Id = mapping.challongePlayer1Id else {
                debugLog("FAILED: No challongePlayer1Id in mapping for match")
                throw ChallongeError.participantMappingNotFound(playerName: winner)
            }
            winnerId = p1Id
            debugLog("Winner is player1: \(winner) → challongePlayer1Id=\(winnerId)")
        } else if localMatch.player2Name == winner {
            guard let p2Id = mapping.challongePlayer2Id else {
                debugLog("FAILED: No challongePlayer2Id in mapping for match")
                throw ChallongeError.participantMappingNotFound(playerName: winner)
            }
            winnerId = p2Id
            debugLog("Winner is player2: \(winner) → challongePlayer2Id=\(winnerId)")
        } else {
            // Fallback: try participant mapping (for backwards compatibility with old data)
            debugLog("Winner '\(winner)' doesn't match player1='\(localMatch.player1Name ?? "nil")' or player2='\(localMatch.player2Name ?? "nil")'")
            debugLog("Falling back to participant mapping lookup...")
            guard let winnerMapping = currentSyncState.participantMappings.first(where: { $0.playerName == winner }) else {
                debugLog("FAILED: No participant mapping found for winner: \(winner)")
                debugLog("  Available participants: \(currentSyncState.participantMappings.map { $0.playerName }.joined(separator: ", "))")
                throw ChallongeError.participantMappingNotFound(playerName: winner)
            }
            winnerId = winnerMapping.challongeParticipantId
            debugLog("Fallback winner mapping: \(winner) → participantId=\(winnerId)")
        }

        // Format the score for Challonge
        let scoresCsv = Self.formatScoresForChallonge(
            player1Score: player1Score,
            player2Score: player2Score,
            player1SetWins: player1SetWins,
            player2SetWins: player2SetWins,
            isBestOf: isBestOf
        )
        debugLog("Formatted score: \(scoresCsv)")

        debugLog("Calling ChallongeService.updateMatch...")
        debugLog("  - tournamentId: \(currentSyncState.challongeUrl)")
        debugLog("  - matchId: \(mapping.challongeMatchId)")
        debugLog("  - winnerId: \(winnerId)")
        debugLog("  - scoresCsv: \(scoresCsv)")

        // Submit to Challonge (retries 3 times with exponential backoff)
        _ = try await challongeService.updateMatch(
            tournamentId: currentSyncState.challongeUrl,
            matchId: mapping.challongeMatchId,
            winnerId: winnerId,
            scoresCsv: scoresCsv
        )

        // Record API call
        currentSyncState.recordApiCall()
        syncState = currentSyncState
        saveSyncState()

        debugLog("SUCCESS: Match \(mapping.challongeMatchId) updated - \(winner) won \(scoresCsv)")
        print("[Challonge] Successfully submitted score for match \(matchId): \(winner) won \(scoresCsv)")

        // Fetch new matches after a delay (in background, don't block)
        // This allows Challonge to generate new rounds after processing the score
        Task {
            await fetchNewMatchesAfterDelay()
        }
    }

    /// Formats scores for Challonge CSV format
    /// - Best Of: Report SET WINS only (e.g., "2-1" for Bo3)
    /// - Single Game: Report point score (e.g., "4-2")
    static func formatScoresForChallonge(
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        isBestOf: Bool
    ) -> String {
        if isBestOf {
            // Best Of: report set wins only
            return "\(player1SetWins)-\(player2SetWins)"
        } else {
            // Single game: report point score
            return "\(player1Score)-\(player2Score)"
        }
    }

    // MARK: - Auto-Fetch New Matches

    /// Fetches only new/open matches from Challonge (called when round completes)
    func fetchNewMatches() async throws {
        guard var currentSyncState = syncState else { return }

        // Fetch only open matches (ready to play)
        let openMatches = try await challongeService.fetchMatches(
            tournamentId: currentSyncState.challongeUrl,
            state: .open
        )

        // Record API call
        currentSyncState.recordApiCall()

        // Create participant lookup
        let participantLookup = createParticipantLookup(from: currentSyncState.participantMappings)

        // Import any matches we don't have locally
        guard var updatedTournament = tournamentManager.currentTournament else {
            syncState = currentSyncState
            saveSyncState()
            return
        }

        var addedCount = 0

        for challongeMatch in openMatches {
            // Check if we already have this match
            if !currentSyncState.matchMappings.contains(where: { $0.challongeMatchId == challongeMatch.id }) {
                // Import new match
                let newMatch = TournamentMatch(
                    roundNumber: challongeMatch.absoluteRound,
                    matchNumber: challongeMatch.suggestedPlayOrder ?? updatedTournament.matches.count,
                    player1Name: challongeMatch.player1Id.flatMap { participantLookup[$0] },
                    player2Name: challongeMatch.player2Id.flatMap { participantLookup[$0] },
                    stage: challongeMatch.isGroupStage ? .group1 : .main
                )

                updatedTournament.matches.append(newMatch)

                // Add mapping with player IDs
                let mapping = ChallongeMatchMapping(
                    localMatchId: newMatch.id,
                    challongeMatchId: challongeMatch.id,
                    challongePlayer1Id: challongeMatch.player1Id,
                    challongePlayer2Id: challongeMatch.player2Id
                )
                currentSyncState.matchMappings.append(mapping)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            // Update Swiss round if applicable
            if updatedTournament.tournamentType == .swiss {
                let maxRound = openMatches.map { $0.absoluteRound }.max() ?? 0
                if maxRound > updatedTournament.currentSwissRound {
                    updatedTournament.currentSwissRound = maxRound
                }
            }

            tournamentManager.setTournament(updatedTournament)
            newMatchCount = addedCount
            print("[Challonge] Imported \(addedCount) new matches")
        }

        currentSyncState.lastSyncedAt = Date()
        syncState = currentSyncState
        saveSyncState()
    }

    /// Fetches new matches after a delay to allow Challonge to process scores and generate new rounds
    /// - Parameter delay: Time to wait before fetching (defaults to postSubmitFetchDelay)
    func fetchNewMatchesAfterDelay(_ delay: TimeInterval? = nil) async {
        let waitTime = delay ?? Self.postSubmitFetchDelay
        debugLog("Waiting \(waitTime)s before fetching new matches...")

        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        debugLog("Fetching new matches from Challonge...")
        do {
            try await fetchNewMatches()
            if newMatchCount > 0 {
                debugLog("Found \(newMatchCount) new match(es)")
            } else {
                debugLog("No new matches available yet")
            }
        } catch {
            debugLog("Failed to fetch new matches: \(error.localizedDescription)")
        }
    }
}
