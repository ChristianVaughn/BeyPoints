//
// ScoringChip.swift
// bitchat
//
// Tappable chips for scoring win conditions.
// Part of BeyScore Tournament System.
//

import SwiftUI

// MARK: - Local Color Aliases and Border Colors

private extension Color {
    // Border colors (darker variants for accessibility)
    static let player1BlueDark = Color(red: 13/255, green: 100/255, blue: 151/255) // #0D6497
    static let player2RedDark = Color(red: 229/255, green: 29/255, blue: 29/255)  // #E51D1D
    static let warningOrangeDark = Color(red: 217/255, green: 119/255, blue: 6/255) // #D97706

    // Alias for scoring warning (uses Color.scoringWarning from Color+Theme.swift)
    static let warningOrange = Color.scoringWarning
}

/// A tappable chip button for scoring a win condition.
struct ScoringChip: View {
    let condition: WinCondition
    let player: Player
    let generation: BeybladeGeneration
    let isDisabled: Bool
    let action: () -> Void

    private var chipColor: Color {
        player == .player1 ? .player1Blue : .player2Red
    }

    private var borderColor: Color {
        player == .player1 ? .player1BlueDark : .player2RedDark
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(condition.chipLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                // Points circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)

                    Text("+\(condition.points(for: generation))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(chipColor)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(width: 94, height: 38)
            .background(chipColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .inset(by: 0.5)
                    .stroke(borderColor, lineWidth: 2)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityLabel("\(condition.chipLabel), \(condition.points(for: generation)) points for \(player == .player1 ? "Player 1" : "Player 2")")
        .accessibilityHint(isDisabled ? "Scoring disabled" : "Double tap to score")
    }
}

/// A chip for the error/penalty/warning flow.
struct ErrorChip: View {
    let player: Player
    let showWarning: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(showWarning ? "PEN" : "ERR")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                // Icon/points circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)

                    if showWarning {
                        Text("+1")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.warningOrange)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.warningOrange)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(width: 94, height: 38)
            .background(Color.warningOrange)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .inset(by: 0.5)
                    .stroke(Color.warningOrangeDark, lineWidth: 2)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityLabel(showWarning ? "Penalty, 1 point for opponent" : "Error warning for \(player == .player1 ? "Player 1" : "Player 2")")
        .accessibilityHint(isDisabled ? "Scoring disabled" : showWarning ? "Double tap to apply penalty" : "Double tap to issue warning")
    }
}

/// A chip for Own Finish (X generation only).
struct OwnFinishChip: View {
    let player: Player
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("OWF")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                // Points circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)

                    Text("+1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.warningOrange)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(width: 94, height: 38)
            .background(Color.warningOrange)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .inset(by: 0.5)
                    .stroke(Color.warningOrangeDark, lineWidth: 2)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityLabel("Own Finish, 1 point for opponent of \(player == .player1 ? "Player 1" : "Player 2")")
        .accessibilityHint(isDisabled ? "Scoring disabled" : "Double tap to score own finish")
    }
}

// MARK: - Warning Indicator Chip

/// A non-interactive chip that shows the warning state.
struct WarningIndicatorChip: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.warningOrange)

            Text("Warning")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
        .accessibilityLabel("Warning active")
    }
}

// MARK: - Chip Row (kept for backwards compatibility, but will be replaced in ScoreCard)

/// A row of scoring chips for a player based on generation.
struct ScoringChipRow: View {
    let player: Player
    let generation: BeybladeGeneration
    let showWarning: Bool
    let canUseOwnFinish: Bool
    let isDisabled: Bool
    let onChipTap: (WinCondition) -> Void
    let onErrorTap: () -> Void
    let onOwnFinishTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Win condition chips based on generation
            ForEach(generation.availableConditions, id: \.self) { condition in
                ScoringChip(
                    condition: condition,
                    player: player,
                    generation: generation,
                    isDisabled: isDisabled
                ) {
                    onChipTap(condition)
                }
            }

            // Error/Penalty chip
            ErrorChip(
                player: player,
                showWarning: showWarning,
                isDisabled: isDisabled,
                action: onErrorTap
            )

            // Own Finish chip (X generation only)
            if canUseOwnFinish {
                OwnFinishChip(
                    player: player,
                    isDisabled: isDisabled,
                    action: onOwnFinishTap
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Scoring Chip - P1") {
    VStack(spacing: 16) {
        ScoringChip(
            condition: .xtreme,
            player: .player1,
            generation: .x,
            isDisabled: false
        ) {}

        ScoringChip(
            condition: .burst,
            player: .player1,
            generation: .x,
            isDisabled: false
        ) {}
    }
    .padding()
}

#Preview("Scoring Chip - P2") {
    VStack(spacing: 16) {
        ScoringChip(
            condition: .xtreme,
            player: .player2,
            generation: .x,
            isDisabled: false
        ) {}

        ScoringChip(
            condition: .burst,
            player: .player2,
            generation: .x,
            isDisabled: false
        ) {}
    }
    .padding()
}

#Preview("Error Chip") {
    VStack(spacing: 16) {
        ErrorChip(
            player: .player1,
            showWarning: false,
            isDisabled: false
        ) {}

        ErrorChip(
            player: .player1,
            showWarning: true,
            isDisabled: false
        ) {}
    }
    .padding()
}

#Preview("Own Finish Chip") {
    OwnFinishChip(
        player: .player1,
        isDisabled: false
    ) {}
    .padding()
}

#Preview("Warning Indicator") {
    WarningIndicatorChip()
        .padding()
}

#Preview("Chip Row - X Gen") {
    ScoringChipRow(
        player: .player1,
        generation: .x,
        showWarning: false,
        canUseOwnFinish: true,
        isDisabled: false,
        onChipTap: { _ in },
        onErrorTap: {},
        onOwnFinishTap: {}
    )
    .padding()
}
