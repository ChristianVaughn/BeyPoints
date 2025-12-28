//
// MatchHistorySheet.swift
// bitchat
//
// Displays the full history of scoring events in a match.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Sheet displaying the match history.
struct MatchHistorySheet: View {
    let history: [HistoryEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if history.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Scoring events will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var historyList: some View {
        List {
            ForEach(Array(history.reversed().enumerated()), id: \.element.id) { index, entry in
                HistoryRow(entry: entry, index: history.count - index)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - History Row

/// A single row in the match history list.
struct HistoryRow: View {
    let entry: HistoryEntry
    let index: Int

    var body: some View {
        if entry.isGameDivider {
            gameDividerRow
        } else {
            scoringEventRow
        }
    }

    private var gameDividerRow: some View {
        HStack {
            Spacer()
            Text("Set \(entry.gameNumber) Complete")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(Color(.tertiarySystemBackground))
        .listRowInsets(EdgeInsets())
    }

    private var scoringEventRow: some View {
        HStack(spacing: 12) {
            // Index number
            Text("#\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            // Condition chip
            ConditionBadge(
                condition: entry.condition,
                isWarning: entry.isWarning
            )

            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.player.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if entry.isWarning {
                    Text("Warning issued")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if entry.isPenalty {
                    Text("+1 to opponent")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Score after
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(entry.score1After)")
                        .foregroundColor(.blue)
                    Text("-")
                        .foregroundColor(.secondary)
                    Text("\(entry.score2After)")
                        .foregroundColor(.red)
                }
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)

                // Set wins if applicable
                if entry.set1WinsAfter > 0 || entry.set2WinsAfter > 0 {
                    HStack(spacing: 4) {
                        Text("Sets:")
                            .foregroundColor(.secondary)
                        Text("\(entry.set1WinsAfter)-\(entry.set2WinsAfter)")
                    }
                    .font(.caption2)
                }
            }

            // Timestamp
            Text(formatTime(entry.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Condition Badge

/// A small badge showing the win condition.
struct ConditionBadge: View {
    let condition: WinCondition
    let isWarning: Bool

    var body: some View {
        Text(isWarning ? "⚠️" : condition.chipLabel)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        if isWarning {
            return .orange
        }
        return condition.chipColor
    }
}

// MARK: - Preview

#Preview {
    MatchHistorySheet(
        history: [
            HistoryEntry(
                player: .player1,
                condition: .xtreme,
                score1After: 3,
                score2After: 0
            ),
            HistoryEntry(
                player: .player2,
                condition: .burst,
                score1After: 3,
                score2After: 2
            ),
            HistoryEntry(
                player: .player1,
                condition: .spin,
                score1After: 4,
                score2After: 2
            )
        ]
    )
}
