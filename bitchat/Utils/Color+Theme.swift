//
// Color+Theme.swift
// bitchat
//
// Theme-aware color definitions for visibility in both light and dark modes.
// Part of BeyPoints Tournament System.
//

import SwiftUI

extension Color {

    // MARK: - Match Status Background Colors

    /// Background for assigned matches (blue tint)
    static func matchAssigned(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.blue.opacity(0.35)
            : Color.blue.opacity(0.2)
    }

    /// Background for in-progress/scoring matches (green tint)
    static func matchInProgress(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.green.opacity(0.35)
            : Color.green.opacity(0.2)
    }

    /// Background for matches awaiting approval (orange tint)
    static func matchAwaitingApproval(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.orange.opacity(0.4)
            : Color.orange.opacity(0.2)
    }

    /// Background for complete matches (green tint)
    static func matchComplete(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.green.opacity(0.35)
            : Color.green.opacity(0.2)
    }

    // MARK: - Match Status Light Backgrounds (for row highlights)

    /// Light background for assigned state
    static func matchAssignedLight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.blue.opacity(0.2)
            : Color.blue.opacity(0.1)
    }

    /// Light background for in-progress state
    static func matchInProgressLight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.green.opacity(0.2)
            : Color.green.opacity(0.1)
    }

    /// Light background for awaiting approval state
    static func matchAwaitingApprovalLight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.orange.opacity(0.25)
            : Color.orange.opacity(0.1)
    }

    // MARK: - Winner/Loser Colors

    /// Background for winner highlight
    static func winnerHighlight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.green.opacity(0.25)
            : Color.green.opacity(0.15)
    }

    /// Background for loser highlight
    static func loserHighlight(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.red.opacity(0.2)
            : Color.red.opacity(0.1)
    }

    // MARK: - Selection Colors

    /// Background for selected items
    static func selectionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.blue.opacity(0.25)
            : Color.blue.opacity(0.1)
    }

    // MARK: - Primary UI Colors

    /// Primary orange color (adjusted for dark mode visibility)
    static func primaryOrange(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.65, blue: 0.25)
            : Color.orange
    }

    /// Primary blue color (adjusted for dark mode visibility)
    static func primaryBlue(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.45, green: 0.65, blue: 1.0)
            : Color.blue
    }
}
