//
// ThemeManager.swift
// bitchat
//
// Manages app theme (system/light/dark) preferences.
// Part of BeyPoints Tournament System.
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: themeKey)
        }
    }

    private let themeKey = "beypoints.theme"

    private init() {
        let saved = UserDefaults.standard.string(forKey: themeKey) ?? "system"
        selectedTheme = AppTheme(rawValue: saved) ?? .system
    }
}
