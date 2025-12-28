//
// AppMode.swift
// bitchat
//
// Defines the app operating modes for the BeyScore Tournament System.
//

import Foundation

/// The operating mode of the app.
enum AppMode: String, Codable, CaseIterable {
    /// Tournament organizer mode - creates tournaments, manages bracket, approves scores
    case master

    /// Scoring station mode - receives match assignments, scores matches, submits results
    case scoreboard

    /// Display name for the mode
    var displayName: String {
        switch self {
        case .master:
            return "Tournament Master"
        case .scoreboard:
            return "Scoreboard"
        }
    }

    /// Description of what this mode does
    var description: String {
        switch self {
        case .master:
            return "Create and manage tournaments, assign matches to scoreboards, approve results"
        case .scoreboard:
            return "Score matches assigned by the tournament master and submit results"
        }
    }

    /// Icon name for the mode
    var iconName: String {
        switch self {
        case .master:
            return "crown.fill"
        case .scoreboard:
            return "rectangle.split.2x1.fill"
        }
    }

    /// Color associated with the mode
    var colorName: String {
        switch self {
        case .master:
            return "orange"
        case .scoreboard:
            return "blue"
        }
    }
}
