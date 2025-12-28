//
// OfflineScoreCache.swift
// bitchat
//
// Caches score submissions when Master is disconnected.
// Part of BeyScore Tournament System.
//

import Foundation
import Combine

/// Manages offline caching of score submissions.
@MainActor
final class OfflineScoreCache: ObservableObject {

    static let shared = OfflineScoreCache()

    // MARK: - Published State

    @Published private(set) var pendingSubmissions: [CachedScoreSubmission] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncAttempt: Date?

    // MARK: - Dependencies

    private let messageHandler = TournamentMessageHandler.shared
    private let reconnectionManager = ReconnectionManager.shared

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3

    // MARK: - Initialization

    private init() {
        loadFromDisk()
        setupObservers()
    }

    private func setupObservers() {
        // Watch for connection state changes to trigger sync
        reconnectionManager.$connectionState
            .filter { $0 == .connected }
            .sink { [weak self] _ in
                Task {
                    await self?.syncPendingSubmissions()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Queues a score submission for sending.
    /// If connected, sends immediately. If disconnected, caches for later.
    func queueScoreSubmission(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        matchHistory: [HistoryEntry]
    ) {
        let submission = CachedScoreSubmission(
            matchId: matchId,
            winner: winner,
            player1Score: player1Score,
            player2Score: player2Score,
            player1SetWins: player1SetWins,
            player2SetWins: player2SetWins,
            matchHistory: matchHistory,
            createdAt: Date(),
            retryCount: 0
        )

        // Try to send immediately if connected
        if reconnectionManager.connectionState.isConnected {
            Task {
                await sendSubmission(submission)
            }
        } else {
            // Cache for later
            addPendingSubmission(submission)
        }
    }

    /// Manually triggers a sync of pending submissions.
    func forcSync() async {
        await syncPendingSubmissions()
    }

    /// Removes a pending submission (e.g., if match was reassigned).
    func removePendingSubmission(matchId: UUID) {
        pendingSubmissions.removeAll { $0.matchId == matchId }
        saveToDisk()
    }

    /// Clears all pending submissions.
    func clearAll() {
        pendingSubmissions.removeAll()
        saveToDisk()
    }

    // MARK: - Sync Logic

    private func syncPendingSubmissions() async {
        guard !isSyncing else { return }
        guard !pendingSubmissions.isEmpty else { return }
        guard reconnectionManager.connectionState.isConnected else { return }

        isSyncing = true
        lastSyncAttempt = Date()

        // Process submissions in order
        var submissionsToRetry: [CachedScoreSubmission] = []

        for submission in pendingSubmissions {
            let success = await sendSubmission(submission)

            if !success {
                var updated = submission
                updated.retryCount += 1

                if updated.retryCount < maxRetryAttempts {
                    submissionsToRetry.append(updated)
                }
                // Otherwise, drop the submission after max retries
            }
        }

        pendingSubmissions = submissionsToRetry
        saveToDisk()

        isSyncing = false
    }

    private func sendSubmission(_ submission: CachedScoreSubmission) async -> Bool {
        // Send via message handler
        messageHandler.submitScore(
            matchId: submission.matchId,
            winner: submission.winner,
            player1Score: submission.player1Score,
            player2Score: submission.player2Score,
            player1SetWins: submission.player1SetWins,
            player2SetWins: submission.player2SetWins,
            history: submission.matchHistory
        )

        // Wait briefly for acknowledgment
        // In a real implementation, you'd wait for an actual response
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // For now, assume success if still connected
        return reconnectionManager.connectionState.isConnected
    }

    private func addPendingSubmission(_ submission: CachedScoreSubmission) {
        // Remove any existing submission for same match
        pendingSubmissions.removeAll { $0.matchId == submission.matchId }
        pendingSubmissions.append(submission)
        saveToDisk()
    }

    // MARK: - Persistence

    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("offline_score_cache.json")
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(pendingSubmissions)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save offline cache: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheURL)
            pendingSubmissions = try JSONDecoder().decode([CachedScoreSubmission].self, from: data)

            // Remove expired submissions (older than 24 hours)
            let cutoff = Date().addingTimeInterval(-86400)
            pendingSubmissions.removeAll { $0.createdAt < cutoff }
            saveToDisk()
        } catch {
            print("Failed to load offline cache: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct CachedScoreSubmission: Codable, Identifiable {
    let id: UUID
    let matchId: UUID
    let winner: String
    let player1Score: Int
    let player2Score: Int
    let player1SetWins: Int
    let player2SetWins: Int
    let matchHistory: [HistoryEntry]
    let createdAt: Date
    var retryCount: Int

    init(
        matchId: UUID,
        winner: String,
        player1Score: Int,
        player2Score: Int,
        player1SetWins: Int,
        player2SetWins: Int,
        matchHistory: [HistoryEntry],
        createdAt: Date,
        retryCount: Int
    ) {
        self.id = UUID()
        self.matchId = matchId
        self.winner = winner
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.player1SetWins = player1SetWins
        self.player2SetWins = player2SetWins
        self.matchHistory = matchHistory
        self.createdAt = createdAt
        self.retryCount = retryCount
    }

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 86400 // 24 hours
    }

    var canRetry: Bool {
        retryCount < 3
    }
}
