//
// AppState.swift
// bitchat
//
// Central app state management for BeyScore Tournament System.
//

import Foundation
import SwiftUI
import Combine

/// Central state manager for the app.
/// Handles mode selection, navigation, and persistence.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Published Properties

    /// The current app mode (master or scoreboard)
    @Published var currentMode: AppMode?

    /// Whether the mode selection has been completed
    @Published var hasSelectedMode: Bool = false

    /// Whether onboarding has been completed
    @Published var hasCompletedOnboarding: Bool = false

    /// Current navigation state
    @Published var navigationPath = NavigationPath()

    // MARK: - Private Properties

    private let modeKey = "beyscore.appMode"
    private let onboardingKey = "beyscore.onboardingComplete"

    // MARK: - Initialization

    private init() {
        loadSavedState()
    }

    // MARK: - Mode Management

    /// Sets the app mode and persists it.
    /// - Parameter mode: The mode to set
    func setMode(_ mode: AppMode) {
        currentMode = mode
        hasSelectedMode = true
        saveState()

        // Also update the room manager's device mode
        TournamentRoomManager.shared.deviceMode = mode == .master ? .master : .scoreboard
    }

    /// Clears the mode selection, returning to mode selection screen.
    func clearMode() {
        currentMode = nil
        hasSelectedMode = false
        saveState()
    }

    /// Marks onboarding as complete.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        saveState()
    }

    // MARK: - Persistence

    private func saveState() {
        let defaults = UserDefaults.standard

        if let mode = currentMode {
            defaults.set(mode.rawValue, forKey: modeKey)
        } else {
            defaults.removeObject(forKey: modeKey)
        }

        defaults.set(hasCompletedOnboarding, forKey: onboardingKey)
    }

    private func loadSavedState() {
        let defaults = UserDefaults.standard

        if let modeString = defaults.string(forKey: modeKey),
           let mode = AppMode(rawValue: modeString) {
            currentMode = mode
            hasSelectedMode = true

            // Sync with room manager
            TournamentRoomManager.shared.deviceMode = mode == .master ? .master : .scoreboard
        }

        hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
    }

    // MARK: - Navigation Helpers

    /// Resets navigation to root.
    func resetNavigation() {
        navigationPath = NavigationPath()
    }
}

// MARK: - Environment Key

private struct AppStateKey: EnvironmentKey {
    @MainActor static let defaultValue: AppState = AppState.shared
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
