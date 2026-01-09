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

    /// Primary green color (adjusted for dark mode visibility)
    static func primaryGreen(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.75, blue: 0.45)
            : Color(red: 0, green: 0.5, blue: 0)
    }

    // MARK: - Scoring Colors

    /// Player 1 scoring color (blue)
    static let player1Blue = Color(red: 16/255, green: 136/255, blue: 201/255)

    /// Player 2 scoring color (red)
    static let player2Red = Color(red: 255/255, green: 85/255, blue: 85/255)

    /// Warning/caution scoring color (orange)
    static let scoringWarning = Color(red: 245/255, green: 158/255, blue: 11/255)

    // MARK: - Status Colors

    /// Success/positive status color
    static func statusSuccess(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.75, blue: 0.45)
            : Color.green
    }

    /// Error/negative status color
    static func statusError(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.4, blue: 0.4)
            : Color.red
    }

    /// Warning/caution status color
    static func statusWarning(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.65, blue: 0.25)
            : Color.orange
    }

    // MARK: - Text Colors

    /// Secondary text color
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.gray
            : Color(white: 0.4)
    }

    // MARK: - Landing Screen Colors

    /// Landing screen background (cream in light mode, black in dark mode)
    static func landingBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black
            : Color(red: 0.98, green: 0.96, blue: 0.94)
    }
}
