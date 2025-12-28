//
// ScoreCard.swift
// bitchat
//
// Displays a player's score and scoring chips.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// A card displaying a player's current score and scoring options.
/// Redesigned to match the reference web app with chips in corners and centered score.
struct ScoreCard: View {
    let player: Player
    let playerName: String
    let score: Int
    let setWins: Int
    let showWarning: Bool
    let generation: BeybladeGeneration
    let bestOf: BestOf
    let canUseOwnFinish: Bool
    let isDisabled: Bool

    let onChipTap: (WinCondition) -> Void
    let onErrorTap: () -> Void
    let onOwnFinishTap: () -> Void

    private var playerColor: Color {
        player == .player1 ? .player1Blue : .player2Red
    }

    private var cardBackgroundColor: Color {
        playerColor.opacity(0.05)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackgroundColor)

                // Content based on player
                if player == .player1 {
                    player1Layout(size: geometry.size)
                } else {
                    player2Layout(size: geometry.size)
                }

                // Centered score
                Text("\(score)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundColor(playerColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: score)
            }
        }
    }

    // MARK: - Player 1 Layout

    /// P1: Name top-left, ERR/OWF top-right, chips bottom corners
    private func player1Layout(size: CGSize) -> some View {
        ZStack {
            // Top-left: Player name + warning
            VStack(alignment: .leading, spacing: 12) {
                PlayerNameRow(
                    playerName: playerName,
                    player: player,
                    setWins: setWins,
                    bestOf: bestOf
                )

                if showWarning {
                    WarningIndicatorChip()
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)

            // Top-right: ERR and OWF stacked
            VStack(spacing: 12) {
                ErrorChip(
                    player: player,
                    showWarning: showWarning,
                    isDisabled: isDisabled,
                    action: onErrorTap
                )

                if canUseOwnFinish {
                    OwnFinishChip(
                        player: player,
                        isDisabled: isDisabled,
                        action: onOwnFinishTap
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(20)

            // Bottom: Scoring chips
            scoringChipsPlayer1(size: size)
        }
    }

    // MARK: - Player 2 Layout

    /// P2: Chips top corners, name bottom-left, ERR/OWF bottom-right
    private func player2Layout(size: CGSize) -> some View {
        ZStack {
            // Top: Scoring chips
            scoringChipsPlayer2(size: size)

            // Bottom-left: Player name + warning
            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                if showWarning {
                    WarningIndicatorChip()
                }

                PlayerNameRow(
                    playerName: playerName,
                    player: player,
                    setWins: setWins,
                    bestOf: bestOf
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(20)

            // Bottom-right: ERR and OWF stacked
            VStack(spacing: 12) {
                Spacer()

                if canUseOwnFinish {
                    OwnFinishChip(
                        player: player,
                        isDisabled: isDisabled,
                        action: onOwnFinishTap
                    )
                }

                ErrorChip(
                    player: player,
                    showWarning: showWarning,
                    isDisabled: isDisabled,
                    action: onErrorTap
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(20)
        }
    }

    // MARK: - Scoring Chips Layouts

    private func scoringChipsPlayer1(size: CGSize) -> some View {
        let conditions = generation.availableConditions

        return HStack {
            // Bottom-left stack
            VStack(alignment: .leading, spacing: 12) {
                Spacer()
                leftColumnChips(conditions: conditions)
            }
            .padding(20)

            Spacer()

            // Bottom-right stack
            VStack(alignment: .trailing, spacing: 12) {
                Spacer()
                rightColumnChips(conditions: conditions)
            }
            .padding(20)
        }
    }

    private func scoringChipsPlayer2(size: CGSize) -> some View {
        let conditions = generation.availableConditions

        return HStack {
            // Top-left stack
            VStack(alignment: .leading, spacing: 12) {
                leftColumnChipsReversed(conditions: conditions)
                Spacer()
            }
            .padding(20)

            Spacer()

            // Top-right stack
            VStack(alignment: .trailing, spacing: 12) {
                rightColumnChipsReversed(conditions: conditions)
                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - Chip Column Helpers

    /// Left column chips for P1 (bottom) - XTR on top, OVR on bottom for X gen
    private func leftColumnChips(conditions: [WinCondition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if conditions.contains(.xtreme) {
                chipButton(for: .xtreme)
            }
            if conditions.contains(.over) {
                chipButton(for: .over)
            }
        }
    }

    /// Right column chips for P1 (bottom) - BST on top, SPF on bottom for X gen
    private func rightColumnChips(conditions: [WinCondition]) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            if conditions.contains(.burst) {
                chipButton(for: .burst)
            }
            if conditions.contains(.spin) {
                chipButton(for: .spin)
            }
        }
    }

    /// Left column chips for P2 (top) - OVR on top, XTR on bottom for X gen
    private func leftColumnChipsReversed(conditions: [WinCondition]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if conditions.contains(.over) {
                chipButton(for: .over)
            }
            if conditions.contains(.xtreme) {
                chipButton(for: .xtreme)
            }
        }
    }

    /// Right column chips for P2 (top) - SPF on top, BST on bottom for X gen
    private func rightColumnChipsReversed(conditions: [WinCondition]) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            if conditions.contains(.spin) {
                chipButton(for: .spin)
            }
            if conditions.contains(.burst) {
                chipButton(for: .burst)
            }
        }
    }

    private func chipButton(for condition: WinCondition) -> some View {
        ScoringChip(
            condition: condition,
            player: player,
            generation: generation,
            isDisabled: isDisabled
        ) {
            onChipTap(condition)
        }
    }
}

// MARK: - Player Name Row

struct PlayerNameRow: View {
    let playerName: String
    let player: Player
    let setWins: Int
    let bestOf: BestOf

    var body: some View {
        HStack(spacing: 8) {
            Text(playerName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            if bestOf != .none {
                SetWinIndicator(
                    wins: setWins,
                    required: bestOf.winsRequired ?? 0
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Set Win Indicator

/// Shows the number of sets won with star icons.
struct SetWinIndicator: View {
    let wins: Int
    let required: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<required, id: \.self) { index in
                Image(systemName: index < wins ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(index < wins ? .yellow : .gray.opacity(0.4))
            }
        }
    }
}

// MARK: - Compact Score Card (Landscape)

/// A more compact square score card for landscape orientation.
struct CompactScoreCard: View {
    let player: Player
    let playerName: String
    let score: Int
    let setWins: Int
    let showWarning: Bool
    let generation: BeybladeGeneration
    let bestOf: BestOf
    let canUseOwnFinish: Bool
    let isDisabled: Bool

    let onChipTap: (WinCondition) -> Void
    let onErrorTap: () -> Void
    let onOwnFinishTap: () -> Void

    private var playerColor: Color {
        player == .player1 ? .player1Blue : .player2Red
    }

    private var cardBackgroundColor: Color {
        playerColor.opacity(0.05)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackgroundColor)

                // Content based on player
                if player == .player1 {
                    player1LandscapeLayout(size: geometry.size)
                } else {
                    player2LandscapeLayout(size: geometry.size)
                }

                // Centered score
                Text("\(score)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(playerColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: score)
            }
        }
    }

    // MARK: - Player 1 Landscape Layout

    private func player1LandscapeLayout(size: CGSize) -> some View {
        let conditions = generation.availableConditions

        return ZStack {
            // Top-left: Player name
            VStack(alignment: .leading, spacing: 8) {
                PlayerNameRow(
                    playerName: playerName,
                    player: player,
                    setWins: setWins,
                    bestOf: bestOf
                )

                if showWarning {
                    WarningIndicatorChip()
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)

            // Top-right: ERR/OWF stacked
            VStack(spacing: 8) {
                ErrorChip(
                    player: player,
                    showWarning: showWarning,
                    isDisabled: isDisabled,
                    action: onErrorTap
                )

                if canUseOwnFinish {
                    OwnFinishChip(
                        player: player,
                        isDisabled: isDisabled,
                        action: onOwnFinishTap
                    )
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)

            // Bottom-left: Scoring chips stacked
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                ForEach(conditions, id: \.self) { condition in
                    ScoringChip(
                        condition: condition,
                        player: player,
                        generation: generation,
                        isDisabled: isDisabled
                    ) {
                        onChipTap(condition)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(16)
        }
    }

    // MARK: - Player 2 Landscape Layout

    private func player2LandscapeLayout(size: CGSize) -> some View {
        let conditions = generation.availableConditions

        return ZStack {
            // Top-right: Scoring chips stacked
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(conditions, id: \.self) { condition in
                    ScoringChip(
                        condition: condition,
                        player: player,
                        generation: generation,
                        isDisabled: isDisabled
                    ) {
                        onChipTap(condition)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)

            // Bottom-left: ERR/OWF stacked
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                if canUseOwnFinish {
                    OwnFinishChip(
                        player: player,
                        isDisabled: isDisabled,
                        action: onOwnFinishTap
                    )
                }

                ErrorChip(
                    player: player,
                    showWarning: showWarning,
                    isDisabled: isDisabled,
                    action: onErrorTap
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(16)

            // Bottom-right: Player name + warning
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                if showWarning {
                    WarningIndicatorChip()
                }

                PlayerNameRow(
                    playerName: playerName,
                    player: player,
                    setWins: setWins,
                    bestOf: bestOf
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(16)
        }
    }
}

// MARK: - Previews

#Preview("Score Card - P1") {
    ScoreCard(
        player: .player1,
        playerName: "Player 1",
        score: 3,
        setWins: 1,
        showWarning: false,
        generation: .x,
        bestOf: .bestOf3,
        canUseOwnFinish: true,
        isDisabled: false,
        onChipTap: { _ in },
        onErrorTap: {},
        onOwnFinishTap: {}
    )
    .frame(height: 350)
    .padding()
}

#Preview("Score Card - P2") {
    ScoreCard(
        player: .player2,
        playerName: "Player 2",
        score: 2,
        setWins: 0,
        showWarning: true,
        generation: .x,
        bestOf: .bestOf3,
        canUseOwnFinish: true,
        isDisabled: false,
        onChipTap: { _ in },
        onErrorTap: {},
        onOwnFinishTap: {}
    )
    .frame(height: 350)
    .padding()
}

#Preview("Score Card - Burst") {
    ScoreCard(
        player: .player1,
        playerName: "Burst Player",
        score: 4,
        setWins: 2,
        showWarning: false,
        generation: .burst,
        bestOf: .bestOf3,
        canUseOwnFinish: false,
        isDisabled: false,
        onChipTap: { _ in },
        onErrorTap: {},
        onOwnFinishTap: {}
    )
    .frame(height: 350)
    .padding()
}

#Preview("Compact Card - Landscape P1") {
    CompactScoreCard(
        player: .player1,
        playerName: "Player 1",
        score: 3,
        setWins: 1,
        showWarning: false,
        generation: .x,
        bestOf: .bestOf3,
        canUseOwnFinish: true,
        isDisabled: false,
        onChipTap: { _ in },
        onErrorTap: {},
        onOwnFinishTap: {}
    )
    .frame(width: 350, height: 350)
    .padding()
}

#Preview("Set Win Indicator") {
    VStack(spacing: 20) {
        SetWinIndicator(wins: 0, required: 2)
        SetWinIndicator(wins: 1, required: 2)
        SetWinIndicator(wins: 2, required: 3)
    }
    .padding()
}
