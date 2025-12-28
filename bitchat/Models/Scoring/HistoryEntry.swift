//
// HistoryEntry.swift
// bitchat
//
// Records individual scoring events in a match.
// Part of BeyScore Tournament System.
//

import Foundation

/// A single entry in the match history, recording a scoring event.
struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let player: Player
    let condition: WinCondition
    let score1After: Int
    let score2After: Int
    let set1WinsAfter: Int
    let set2WinsAfter: Int
    let timestamp: Date
    let isWarning: Bool
    let isPenalty: Bool
    let isGameDivider: Bool
    let gameNumber: Int

    init(
        id: UUID = UUID(),
        player: Player,
        condition: WinCondition,
        score1After: Int,
        score2After: Int,
        set1WinsAfter: Int = 0,
        set2WinsAfter: Int = 0,
        timestamp: Date = Date(),
        isWarning: Bool = false,
        isPenalty: Bool = false,
        isGameDivider: Bool = false,
        gameNumber: Int = 1
    ) {
        self.id = id
        self.player = player
        self.condition = condition
        self.score1After = score1After
        self.score2After = score2After
        self.set1WinsAfter = set1WinsAfter
        self.set2WinsAfter = set2WinsAfter
        self.timestamp = timestamp
        self.isWarning = isWarning
        self.isPenalty = isPenalty
        self.isGameDivider = isGameDivider
        self.gameNumber = gameNumber
    }

    /// Creates a game divider entry.
    static func gameDivider(
        score1After: Int,
        score2After: Int,
        set1WinsAfter: Int,
        set2WinsAfter: Int,
        gameNumber: Int
    ) -> HistoryEntry {
        return HistoryEntry(
            player: .player1,  // Doesn't matter for divider
            condition: .spin,   // Doesn't matter for divider
            score1After: score1After,
            score2After: score2After,
            set1WinsAfter: set1WinsAfter,
            set2WinsAfter: set2WinsAfter,
            isGameDivider: true,
            gameNumber: gameNumber
        )
    }

    /// Display text for the history entry.
    var displayText: String {
        if isGameDivider {
            return "Set \(gameNumber) Complete"
        }

        if isWarning {
            return "\(player.displayName) - Warning"
        }

        let pointsText: String
        if condition.awardsToOpponent {
            pointsText = "+1 to \(player.opponent.displayName)"
        } else {
            pointsText = condition.displayName
        }

        return "\(player.displayName) - \(pointsText)"
    }

    /// Short text for compact display.
    var shortText: String {
        if isGameDivider {
            return "---"
        }
        return "\(condition.chipLabel)"
    }
}

// MARK: - History Entry Array Extension

extension Array where Element == HistoryEntry {

    /// Encodes the history to JSON for transmission.
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// Decodes history from JSON.
    static func fromJSON(_ json: String) -> [HistoryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8),
              let entries = try? decoder.decode([HistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
