//
// TournamentCreationView.swift
// bitchat
//
// Tournament creation interface for Master mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Tournament creation view for Master mode.
struct TournamentCreationView: View {
    @StateObject private var viewModel = TournamentCreationViewModel()
    @Environment(\.dismiss) private var dismiss

    let onTournamentCreated: (Tournament) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Tournament Info Section
                Section {
                    TextField("Tournament Name", text: $viewModel.tournamentName)
                        .textContentType(.name)

                    HStack {
                        Text("Room Code")
                        Spacer()
                        Text(viewModel.roomCode)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)

                        Button {
                            viewModel.regenerateRoomCode()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("Tournament Info")
                }

                // Tournament Format Section
                Section {
                    Picker("Format", selection: $viewModel.tournamentType) {
                        ForEach(TournamentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                } header: {
                    Text("Tournament Format")
                } footer: {
                    Text(viewModel.tournamentType.description)
                }

                // Multi-Stage Section (for non-elimination formats)
                if viewModel.showMultiStageOptions {
                    Section {
                        Toggle("Multi-Stage Tournament", isOn: $viewModel.isMultiStage)

                        if viewModel.isMultiStage {
                            Picker("Finals Format", selection: $viewModel.finalsType) {
                                Text("Single Elimination").tag(TournamentType.singleElimination)
                                Text("Double Elimination").tag(TournamentType.doubleElimination)
                            }

                            Picker("Finals Size", selection: $viewModel.finalsSize) {
                                Text("Top 4").tag(4)
                                Text("Top 8").tag(8)
                                Text("Top 16").tag(16)
                                Text("Top 32").tag(32)
                            }

                            Divider()

                            // Finals match settings
                            Picker("Finals Match Type", selection: $viewModel.finalsMatchType) {
                                Text("Same as Stage 1").tag(nil as MatchType?)
                                ForEach(MatchType.availableTypes(for: viewModel.generation), id: \.self) { type in
                                    Text(type.displayName).tag(type as MatchType?)
                                }
                            }

                            Picker("Finals Best Of", selection: $viewModel.finalsBestOf) {
                                Text("Same as Stage 1").tag(nil as BestOf?)
                                ForEach(BestOf.allCases, id: \.self) { bo in
                                    Text(bo.displayName).tag(bo as BestOf?)
                                }
                            }
                        }
                    } header: {
                        Text("Tournament Stages")
                    } footer: {
                        if viewModel.isMultiStage {
                            Text("Top \(viewModel.finalsSize) players from \(viewModel.tournamentType.displayName) advance to \(viewModel.finalsType.displayName) finals.")
                        }
                    }
                }

                // Players Section
                Section {
                    PlayerListEditor(players: $viewModel.players)
                } header: {
                    HStack {
                        Text("Players (\(viewModel.players.count))")
                        Spacer()
                        if viewModel.players.count >= 2 {
                            Text(viewModel.roundsDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text(viewModel.playersFooterText)
                }

                // Match Settings Section
                Section {
                    // Generation
                    Picker("Generation", selection: $viewModel.generation) {
                        ForEach(BeybladeGeneration.allCases, id: \.self) { gen in
                            Text(gen.displayName).tag(gen)
                        }
                    }

                    // Match Type
                    Picker("Match Type", selection: $viewModel.matchType) {
                        ForEach(MatchType.availableTypes(for: viewModel.generation), id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    // Best Of
                    Picker("Best Of", selection: $viewModel.bestOf) {
                        ForEach(BestOf.allCases, id: \.self) { bestOf in
                            Text(bestOf.displayName).tag(bestOf)
                        }
                    }

                    // Own Finish (X only)
                    if viewModel.generation.supportsOwnFinish {
                        Toggle("Own Finish Enabled", isOn: $viewModel.ownFinishEnabled)
                    }
                } header: {
                    Text("Match Settings")
                }

                // Shuffle Option
                Section {
                    Toggle("Shuffle Players", isOn: $viewModel.shufflePlayers)
                } footer: {
                    Text("Randomizes player seeding when creating the bracket.")
                }

                // Preview Section
                if viewModel.canCreateTournament {
                    Section {
                        BracketPreview(
                            playerCount: viewModel.players.count,
                            numberOfRounds: viewModel.numberOfRounds,
                            tournamentType: viewModel.tournamentType,
                            isMultiStage: viewModel.isMultiStage,
                            finalsSize: viewModel.finalsSize
                        )
                    } header: {
                        Text("Tournament Summary")
                    }
                }
            }
            .navigationTitle("Create Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let tournament = viewModel.createTournament() {
                            onTournamentCreated(tournament)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canCreateTournament)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class TournamentCreationViewModel: ObservableObject {
    @Published var tournamentName: String = ""
    @Published var roomCode: String = ""
    @Published var players: [String] = []
    @Published var generation: BeybladeGeneration = .x
    @Published var matchType: MatchType = .points4
    @Published var bestOf: BestOf = .none
    @Published var ownFinishEnabled: Bool = false
    @Published var shufflePlayers: Bool = false

    // Tournament format
    @Published var tournamentType: TournamentType = .singleElimination
    @Published var isMultiStage: Bool = false
    @Published var finalsType: TournamentType = .singleElimination
    @Published var finalsSize: Int = 8

    // Finals-specific match settings (nil = same as stage 1)
    @Published var finalsMatchType: MatchType?
    @Published var finalsBestOf: BestOf?

    init() {
        regenerateRoomCode()
    }

    var canCreateTournament: Bool {
        !tournamentName.trimmingCharacters(in: .whitespaces).isEmpty &&
        players.count >= 2 &&
        roomCode.count == 6 &&
        (!isMultiStage || finalsSize <= players.count)
    }

    /// Whether to show multi-stage options.
    var showMultiStageOptions: Bool {
        !tournamentType.isEliminationFormat
    }

    /// Number of rounds based on tournament type.
    var numberOfRounds: Int {
        guard players.count > 1 else { return 0 }

        switch tournamentType {
        case .singleElimination:
            return Int(ceil(log2(Double(players.count))))
        case .doubleElimination:
            let winnerRounds = Int(ceil(log2(Double(players.count))))
            return winnerRounds * 2 + 1
        case .swiss:
            return SwissGenerator.numberOfRounds(for: players.count)
        case .roundRobin:
            return RoundRobinGenerator.numberOfRounds(for: players.count)
        case .groupRoundRobin:
            let groupSize = players.count / 2
            return RoundRobinGenerator.numberOfRounds(for: groupSize)
        }
    }

    /// Description of rounds for display.
    var roundsDescription: String {
        switch tournamentType {
        case .singleElimination, .doubleElimination:
            return "\(numberOfRounds) rounds"
        case .swiss:
            return "\(numberOfRounds) Swiss rounds"
        case .roundRobin:
            return "\(RoundRobinGenerator.totalMatches(for: players.count)) matches"
        case .groupRoundRobin:
            let groupSize = players.count / 2
            let matchesPerGroup = RoundRobinGenerator.totalMatches(for: groupSize)
            return "2 groups, \(matchesPerGroup * 2) matches"
        }
    }

    /// Footer text for players section.
    var playersFooterText: String {
        switch tournamentType {
        case .singleElimination, .doubleElimination:
            return "Minimum 2 players required. Players are seeded in order (drag to reorder)."
        case .swiss:
            return "Minimum 2 players. Players will be paired each round based on standings."
        case .roundRobin:
            return "Every player will play every other player once."
        case .groupRoundRobin:
            return "Players will be divided into 2 equal groups. Minimum 4 players recommended."
        }
    }

    func regenerateRoomCode() {
        roomCode = RoomCode.generate().code
    }

    func createTournament() -> Tournament? {
        guard canCreateTournament else { return nil }

        let filteredPlayers = players.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard filteredPlayers.count >= 2 else { return nil }

        // Build stage config
        var stageConfig = TournamentStageConfig()
        stageConfig.isMultiStage = isMultiStage && showMultiStageOptions
        stageConfig.stage1Type = tournamentType
        stageConfig.finalsType = finalsType
        stageConfig.finalsSize = finalsSize
        stageConfig.finalsMatchType = finalsMatchType
        stageConfig.finalsBestOf = finalsBestOf

        return Tournament.create(
            name: tournamentName.trimmingCharacters(in: .whitespaces),
            roomCode: roomCode,
            players: filteredPlayers,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            tournamentType: tournamentType,
            stageConfig: stageConfig,
            shuffle: shufflePlayers
        )
    }
}

// MARK: - Bracket Preview

struct BracketPreview: View {
    let playerCount: Int
    let numberOfRounds: Int
    let tournamentType: TournamentType
    let isMultiStage: Bool
    let finalsSize: Int

    var body: some View {
        HStack(spacing: 24) {
            // Players
            Label("\(playerCount)", systemImage: "person.2")

            // Rounds
            Label("\(numberOfRounds)", systemImage: "rectangle.3.group")

            // Matches
            Label("\(numberOfMatches)", systemImage: "sportscourt")
        }
        .font(.subheadline)
    }

    private var numberOfMatches: Int {
        var total = stage1Matches

        // Add finals matches if multi-stage
        if isMultiStage && finalsSize > 0 {
            total += finalsSize - 1  // Single elimination finals
        }

        return total
    }

    private var stage1Matches: Int {
        switch tournamentType {
        case .singleElimination:
            return playerCount - 1
        case .doubleElimination:
            // Winners: n-1, Losers: n-2, Grand Finals: 1-2
            return (playerCount - 1) + (playerCount - 2) + 2
        case .swiss:
            // players/2 matches per round * rounds
            let rounds = SwissGenerator.numberOfRounds(for: playerCount)
            return (playerCount / 2) * rounds
        case .roundRobin:
            return RoundRobinGenerator.totalMatches(for: playerCount)
        case .groupRoundRobin:
            let groupSize = playerCount / 2
            return RoundRobinGenerator.totalMatches(for: groupSize) * 2
        }
    }
}

// MARK: - Player List Editor

struct PlayerListEditor: View {
    @Binding var players: [String]
    @State private var newPlayerName: String = ""
    @State private var editingIndex: Int? = nil
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        // Existing players list
        ForEach(Array(players.enumerated()), id: \.offset) { index, player in
            HStack {
                Text("\(index + 1).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)

                if editingIndex == index {
                    TextField("Player Name", text: Binding(
                        get: { players[index] },
                        set: { players[index] = $0 }
                    ))
                    .onSubmit {
                        editingIndex = nil
                    }
                } else {
                    Text(player)
                        .onTapGesture {
                            editingIndex = index
                        }
                }

                Spacer()

                // Seed badge
                SeedBadge(seed: index + 1)
            }
        }
        .onDelete { indexSet in
            players.remove(atOffsets: indexSet)
        }
        .onMove { from, to in
            players.move(fromOffsets: from, toOffset: to)
        }

        // Add new player
        HStack {
            TextField("Add Player", text: $newPlayerName)
                .focused($isAddFieldFocused)
                .onSubmit {
                    addPlayer()
                }

            Button {
                addPlayer()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
            .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        // Bulk import
        Button {
            // Show paste dialog
        } label: {
            Label("Import from Text", systemImage: "doc.on.clipboard")
        }
        .buttonStyle(.borderless)
    }

    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        players.append(trimmed)
        newPlayerName = ""
        isAddFieldFocused = true
    }
}

struct SeedBadge: View {
    let seed: Int

    var body: some View {
        Text("#\(seed)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(seedColor.opacity(0.2))
            .foregroundColor(seedColor)
            .cornerRadius(4)
    }

    private var seedColor: Color {
        switch seed {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

#Preview {
    TournamentCreationView { tournament in
        print("Created tournament: \(tournament.name)")
    }
}
