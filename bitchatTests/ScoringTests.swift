//
// ScoringTests.swift
// bitchatTests
//
// Unit tests for scoring logic.
// Part of BeyScore Tournament System.
//

import XCTest
@testable import bitchat

final class ScoringTests: XCTestCase {

    // MARK: - Point Value Tests

    func testXtremePointValue() {
        // Xtreme is only available in X generation and worth 3 points
        XCTAssertEqual(WinCondition.xtreme.pointValue(for: .x), 3)
    }

    func testBurstPointValue() {
        // Burst is worth 2 points in X and Burst generations
        XCTAssertEqual(WinCondition.burst.pointValue(for: .x), 2)
        XCTAssertEqual(WinCondition.burst.pointValue(for: .burst), 2)
    }

    func testOverPointValue() {
        // Over is worth 2 points in all generations except Burst (1 point)
        XCTAssertEqual(WinCondition.over.pointValue(for: .x), 2)
        XCTAssertEqual(WinCondition.over.pointValue(for: .burst), 1)
        XCTAssertEqual(WinCondition.over.pointValue(for: .metalFight), 2)
        XCTAssertEqual(WinCondition.over.pointValue(for: .plastics), 2)
    }

    func testSpinPointValue() {
        // Spin is worth 1 point in all generations
        XCTAssertEqual(WinCondition.spin.pointValue(for: .x), 1)
        XCTAssertEqual(WinCondition.spin.pointValue(for: .burst), 1)
        XCTAssertEqual(WinCondition.spin.pointValue(for: .metalFight), 1)
        XCTAssertEqual(WinCondition.spin.pointValue(for: .plastics), 1)
    }

    // MARK: - Generation Support Tests

    func testXGenerationSupports() {
        XCTAssertTrue(BeybladeGeneration.x.supportsXtreme)
        XCTAssertTrue(BeybladeGeneration.x.supportsBurst)
        XCTAssertTrue(BeybladeGeneration.x.supportsOwnFinish)
    }

    func testBurstGenerationSupports() {
        XCTAssertFalse(BeybladeGeneration.burst.supportsXtreme)
        XCTAssertTrue(BeybladeGeneration.burst.supportsBurst)
        XCTAssertFalse(BeybladeGeneration.burst.supportsOwnFinish)
    }

    func testMetalFightGenerationSupports() {
        XCTAssertFalse(BeybladeGeneration.metalFight.supportsXtreme)
        XCTAssertFalse(BeybladeGeneration.metalFight.supportsBurst)
        XCTAssertFalse(BeybladeGeneration.metalFight.supportsOwnFinish)
    }

    // MARK: - Available Win Conditions Tests

    func testXGenerationWinConditions() {
        let conditions = BeybladeGeneration.x.availableWinConditions
        XCTAssertTrue(conditions.contains(.xtreme))
        XCTAssertTrue(conditions.contains(.burst))
        XCTAssertTrue(conditions.contains(.over))
        XCTAssertTrue(conditions.contains(.spin))
    }

    func testBurstGenerationWinConditions() {
        let conditions = BeybladeGeneration.burst.availableWinConditions
        XCTAssertFalse(conditions.contains(.xtreme))
        XCTAssertTrue(conditions.contains(.burst))
        XCTAssertTrue(conditions.contains(.over))
        XCTAssertTrue(conditions.contains(.spin))
    }

    func testMetalFightGenerationWinConditions() {
        let conditions = BeybladeGeneration.metalFight.availableWinConditions
        XCTAssertFalse(conditions.contains(.xtreme))
        XCTAssertFalse(conditions.contains(.burst))
        XCTAssertTrue(conditions.contains(.over))
        XCTAssertTrue(conditions.contains(.spin))
    }

    // MARK: - Match Type Tests

    func testXGenerationMatchTypes() {
        let types = BeybladeGeneration.x.availableMatchTypes
        XCTAssertTrue(types.contains(.points3))
        XCTAssertTrue(types.contains(.points4))
        XCTAssertTrue(types.contains(.points5))
        XCTAssertTrue(types.contains(.noLimit))
    }

    func testBurstGenerationMatchTypes() {
        let types = BeybladeGeneration.burst.availableMatchTypes
        XCTAssertTrue(types.contains(.points3))
        XCTAssertTrue(types.contains(.points4))
        XCTAssertTrue(types.contains(.points5))
        XCTAssertFalse(types.contains(.noLimit))
    }

    // MARK: - Game State Tests

    func testInitialGameState() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        let state = GameState.create(config: config)

        XCTAssertEqual(state.player1Score, 0)
        XCTAssertEqual(state.player2Score, 0)
        XCTAssertEqual(state.player1SetWins, 0)
        XCTAssertEqual(state.player2SetWins, 0)
        XCTAssertEqual(state.currentGameNumber, 1)
        XCTAssertFalse(state.isGameComplete)
        XCTAssertFalse(state.isMatchComplete)
    }

    func testScoreApplication() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply Xtreme finish for player 1 (3 points)
        state = state.withScore(player: .player1, condition: .xtreme)

        XCTAssertEqual(state.player1Score, 3)
        XCTAssertEqual(state.player2Score, 0)
        XCTAssertEqual(state.matchHistory.count, 1)
    }

    func testGameCompletion() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply Xtreme + Burst = 5 points, game should complete
        state = state.withScore(player: .player1, condition: .xtreme)  // 3 points
        XCTAssertFalse(state.isGameComplete)

        state = state.withScore(player: .player1, condition: .burst)   // +2 = 5 points
        XCTAssertTrue(state.isGameComplete)
        XCTAssertEqual(state.currentGameWinner, .player1)
    }

    func testBestOfSeries() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .bestOf3,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Win first game
        state = state.withScore(player: .player1, condition: .xtreme)
        state = state.withScore(player: .player1, condition: .burst)
        XCTAssertTrue(state.isGameComplete)
        XCTAssertFalse(state.isMatchComplete)

        // Advance to next game
        state = state.withGameComplete()
        XCTAssertEqual(state.player1SetWins, 1)
        XCTAssertEqual(state.player1Score, 0)
        XCTAssertEqual(state.currentGameNumber, 2)

        // Win second game
        state = state.withScore(player: .player1, condition: .xtreme)
        state = state.withScore(player: .player1, condition: .burst)
        state = state.withGameComplete()

        XCTAssertEqual(state.player1SetWins, 2)
        XCTAssertTrue(state.isMatchComplete)
        XCTAssertEqual(state.matchWinner, .player1)
    }

    func testPenaltyScoring() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply penalty to player 1 (gives 1 point to player 2)
        state = state.withPenalty(player: .player1)

        XCTAssertEqual(state.player1Score, 0)
        XCTAssertEqual(state.player2Score, 1)
    }

    func testOwnFinishScoring() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: true,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply own finish to player 1 (gives 1 point to player 2)
        state = state.withOwnFinish(player: .player1)

        XCTAssertEqual(state.player1Score, 0)
        XCTAssertEqual(state.player2Score, 1)
    }

    func testUndoScore() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply some scores
        state = state.withScore(player: .player1, condition: .xtreme)
        XCTAssertEqual(state.player1Score, 3)

        // Undo
        state = state.undo()
        XCTAssertEqual(state.player1Score, 0)
        XCTAssertTrue(state.matchHistory.isEmpty)
    }

    // MARK: - Warning Flow Tests

    func testWarningFlow() {
        let config = MatchConfiguration(
            generation: .x,
            matchType: .points5,
            bestOf: .none,
            ownFinishEnabled: false,
            player1Name: "Player 1",
            player2Name: "Player 2"
        )
        var state = GameState.create(config: config)

        // Apply warning
        state = state.withWarning(player: .player1)
        XCTAssertTrue(state.p1ShowWarning)
        XCTAssertEqual(state.player1Score, 0)
        XCTAssertEqual(state.player2Score, 0)

        // Apply penalty (after warning)
        state = state.withPenalty(player: .player1)
        XCTAssertFalse(state.p1ShowWarning)
        XCTAssertEqual(state.player2Score, 1)
    }
}

// MARK: - Bracket Generator Tests

final class BracketGeneratorTests: XCTestCase {

    func testTwoPlayerBracket() {
        let players = ["Player 1", "Player 2"]
        let matches = BracketGenerator.generateBracket(players: players)

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].player1Name, "Player 1")
        XCTAssertEqual(matches[0].player2Name, "Player 2")
    }

    func testFourPlayerBracket() {
        let players = ["P1", "P2", "P3", "P4"]
        let matches = BracketGenerator.generateBracket(players: players)

        // 3 matches: 2 in round 1, 1 final
        XCTAssertEqual(matches.count, 3)

        let round1 = matches.filter { $0.roundNumber == 1 }
        let finals = matches.filter { $0.roundNumber == 2 }

        XCTAssertEqual(round1.count, 2)
        XCTAssertEqual(finals.count, 1)
    }

    func testByeHandling() {
        let players = ["P1", "P2", "P3"]
        let matches = BracketGenerator.generateBracket(players: players)

        // 3 players = 4-bracket with 1 bye
        // One match should be complete (bye)
        let byeMatches = matches.filter { $0.isBye && $0.status == .complete }
        XCTAssertEqual(byeMatches.count, 1)

        // Winner of bye should be advanced to next round
        let finals = matches.filter { $0.roundNumber == 2 }
        XCTAssertTrue(finals[0].player1Name != nil || finals[0].player2Name != nil)
    }

    func testEightPlayerBracket() {
        let players = ["P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8"]
        let matches = BracketGenerator.generateBracket(players: players)

        // 7 matches: 4 in round 1, 2 in round 2, 1 final
        XCTAssertEqual(matches.count, 7)

        let round1 = matches.filter { $0.roundNumber == 1 }
        let round2 = matches.filter { $0.roundNumber == 2 }
        let finals = matches.filter { $0.roundNumber == 3 }

        XCTAssertEqual(round1.count, 4)
        XCTAssertEqual(round2.count, 2)
        XCTAssertEqual(finals.count, 1)
    }

    func testNextMatchLinking() {
        let players = ["P1", "P2", "P3", "P4"]
        let matches = BracketGenerator.generateBracket(players: players)

        let round1 = matches.filter { $0.roundNumber == 1 }
        let finals = matches.filter { $0.roundNumber == 2 }

        // Round 1 matches should link to finals
        for match in round1 {
            XCTAssertEqual(match.nextMatchId, finals[0].id)
        }
    }
}

// MARK: - History Entry Tests

final class HistoryEntryTests: XCTestCase {

    func testHistoryEntryEncoding() {
        let entry = HistoryEntry(
            player: .player1,
            condition: .xtreme,
            score1After: 3,
            score2After: 0,
            set1WinsAfter: 0,
            set2WinsAfter: 0
        )

        let encoded = entry.encode()
        XCTAssertEqual(encoded.count, HistoryEntry.encodedSize)

        // Decode and verify
        let decoded = HistoryEntry.decode(from: encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.player, .player1)
        XCTAssertEqual(decoded?.condition, .xtreme)
        XCTAssertEqual(decoded?.score1After, 3)
        XCTAssertEqual(decoded?.score2After, 0)
    }

    func testHistoryListEncodingDecoding() {
        let entries = [
            HistoryEntry(player: .player1, condition: .xtreme, score1After: 3, score2After: 0, set1WinsAfter: 0, set2WinsAfter: 0),
            HistoryEntry(player: .player2, condition: .burst, score1After: 3, score2After: 2, set1WinsAfter: 0, set2WinsAfter: 0),
            HistoryEntry(player: .player1, condition: .spin, score1After: 4, score2After: 2, set1WinsAfter: 0, set2WinsAfter: 0)
        ]

        let encoded = HistoryEntry.encodeList(entries)
        let decoded = HistoryEntry.decodeList(from: encoded)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].condition, .xtreme)
        XCTAssertEqual(decoded[1].condition, .burst)
        XCTAssertEqual(decoded[2].condition, .spin)
    }
}
