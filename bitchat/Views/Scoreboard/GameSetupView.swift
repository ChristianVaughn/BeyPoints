//
// GameSetupView.swift
// bitchat
//
// Configuration screen for setting up a new Beyblade match.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for configuring a new match before starting.
struct GameSetupView: View {
    @StateObject private var config = GameSetupViewModel()
    @Environment(\.dismiss) private var dismiss

    var onStart: ((MatchConfiguration) -> Void)?

    var body: some View {
        NavigationView {
            Form {
                // Player Names Section
                Section("Players") {
                    TextField("Player 1 Name", text: $config.player1Name)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Player 2 Name", text: $config.player2Name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                // Generation Section
                Section("Generation") {
                    Picker("Beyblade Generation", selection: $config.generation) {
                        ForEach(BeybladeGeneration.allCases) { gen in
                            Text(gen.displayName).tag(gen)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Match Type Section
                Section("Match Type") {
                    Picker("Points to Win", selection: $config.matchType) {
                        ForEach(config.availableMatchTypes) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Best Of Section
                Section("Format") {
                    Picker("Best Of", selection: $config.bestOf) {
                        ForEach(BestOf.allCases) { bo in
                            Text(bo.displayName).tag(bo)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // X Generation Options
                if config.generation == .x {
                    Section("X Generation Options") {
                        Toggle("Enable Own Finish", isOn: $config.ownFinishEnabled)
                    }
                }

                // Summary Section
                Section("Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Generation:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(config.generation.displayName)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Win Condition:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(config.matchType.displayName)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Format:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(config.bestOf.displayName)
                                .fontWeight(.medium)
                        }

                        if config.generation == .x && config.ownFinishEnabled {
                            HStack {
                                Text("Own Finish:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Enabled")
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Game Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start") {
                        startGame()
                    }
                    .fontWeight(.semibold)
                    .disabled(!config.isValid)
                }
            }
        }
    }

    private func startGame() {
        let matchConfig = config.createConfiguration()
        onStart?(matchConfig)
        dismiss()
    }
}

// MARK: - Game Setup View Model

/// View model for game setup configuration.
@MainActor
final class GameSetupViewModel: ObservableObject {
    @Published var player1Name: String = "Player 1"
    @Published var player2Name: String = "Player 2"
    @Published var generation: BeybladeGeneration = .x {
        didSet {
            // Update match type to default for this generation
            if !availableMatchTypes.contains(matchType) {
                matchType = generation.defaultMatchType
            }
            // Disable own finish if not X generation
            if generation != .x {
                ownFinishEnabled = false
            }
        }
    }
    @Published var matchType: MatchType = .points4
    @Published var bestOf: BestOf = .none
    @Published var ownFinishEnabled: Bool = false

    var availableMatchTypes: [MatchType] {
        MatchType.availableTypes(for: generation)
    }

    var isValid: Bool {
        !player1Name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !player2Name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func createConfiguration() -> MatchConfiguration {
        MatchConfiguration(
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            player1Name: player1Name.trimmingCharacters(in: .whitespaces),
            player2Name: player2Name.trimmingCharacters(in: .whitespaces)
        )
    }
}

// MARK: - Quick Setup Presets

extension GameSetupView {
    /// Creates a setup view with preset configuration for assigned matches.
    static func forAssignedMatch(
        player1: String,
        player2: String,
        generation: BeybladeGeneration,
        matchType: MatchType,
        bestOf: BestOf,
        ownFinishEnabled: Bool,
        onStart: @escaping (MatchConfiguration) -> Void
    ) -> GameSetupView {
        let view = GameSetupView(onStart: onStart)
        // Note: In SwiftUI, we'd use a different approach for presets
        // This is a placeholder for the assigned match flow
        return view
    }
}

// MARK: - Preview

#Preview {
    GameSetupView { config in
        print("Starting game with config: \(config)")
    }
}
