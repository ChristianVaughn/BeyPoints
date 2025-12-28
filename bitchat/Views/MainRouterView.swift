//
// MainRouterView.swift
// bitchat
//
// Routes between mode selection and main app views based on app state.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Root view that routes based on app mode selection.
struct MainRouterView: View {
    @StateObject private var appState = AppState.shared
    @EnvironmentObject var chatViewModel: ChatViewModel

    var body: some View {
        Group {
            if !appState.hasSelectedMode {
                // Show mode selection on first launch
                ModeSelectionView()
                    .transition(.opacity)
            } else if let mode = appState.currentMode {
                // Route based on mode
                switch mode {
                case .master:
                    MasterMainView()
                        .environmentObject(chatViewModel)
                        .transition(.opacity)
                case .scoreboard:
                    ScoreboardCoordinator()
                        .environmentObject(chatViewModel)
                        .transition(.opacity)
                }
            } else {
                // Fallback - should not happen
                ModeSelectionView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasSelectedMode)
        .animation(.easeInOut(duration: 0.3), value: appState.currentMode)
    }
}

// MARK: - Preview

#Preview("Router - No Mode") {
    MainRouterView()
}
