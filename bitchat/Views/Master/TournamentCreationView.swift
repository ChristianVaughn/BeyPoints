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
                tournamentInfoSection
                stageTypeSection
                formatSelectionSection
                generationSection
                matchSettingsSection
                if viewModel.isMultiStage {
                    finalsSettingsSection
                }
                playersSection
                optionsSection
                if viewModel.canCreateTournament {
                    previewSection
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

    // MARK: - Tournament Info Section

    private var tournamentInfoSection: some View {
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
    }

    // MARK: - Stage Type Section (NEW)

    private var stageTypeSection: some View {
        Section {
            Picker("Structure", selection: $viewModel.isMultiStage) {
                Text("Single Stage").tag(false)
                Text("Multi-Stage").tag(true)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Tournament Structure")
        } footer: {
            Text(viewModel.isMultiStage
                ? "Preliminary stage (Swiss/Round Robin) followed by finals bracket."
                : "All players compete in one bracket or format.")
        }
    }

    // MARK: - Format Selection Section

    private var formatSelectionSection: some View {
        Section {
            if viewModel.isMultiStage {
                // Multi-stage: separate preliminary and finals pickers
                Picker("Preliminary", selection: $viewModel.preliminaryFormat) {
                    Text("Swiss").tag(TournamentType.swiss)
                    Text("Round Robin").tag(TournamentType.roundRobin)
                }

                Picker("Finals", selection: $viewModel.finalsType) {
                    Text("Single Elimination").tag(TournamentType.singleElimination)
                    Text("Double Elimination").tag(TournamentType.doubleElimination)
                }

                Picker("Finals Size", selection: $viewModel.finalsSize) {
                    Text("Top 4").tag(4)
                    Text("Top 8").tag(8)
                    Text("Top 16").tag(16)
                    Text("Top 32").tag(32)
                }
            } else {
                // Single stage: all format options (no Group RR for v1.0)
                Picker("Format", selection: $viewModel.tournamentType) {
                    Text("Single Elimination").tag(TournamentType.singleElimination)
                    Text("Double Elimination").tag(TournamentType.doubleElimination)
                    Text("Swiss").tag(TournamentType.swiss)
                    Text("Round Robin").tag(TournamentType.roundRobin)
                }
            }
        } header: {
            Text("Format")
        } footer: {
            if viewModel.isMultiStage {
                Text("Top \(viewModel.finalsSize) players advance from \(viewModel.preliminaryFormat.displayName) to \(viewModel.finalsType.displayName) finals.")
            } else {
                Text(viewModel.tournamentType.description)
            }
        }
    }

    // MARK: - Generation Section

    private var generationSection: some View {
        Section {
            Picker("Generation", selection: $viewModel.generation) {
                ForEach(BeybladeGeneration.allCases, id: \.self) { gen in
                    Text(gen.displayName).tag(gen)
                }
            }
        } header: {
            Text("Generation")
        }
    }

    // MARK: - Match Settings Section

    private var matchSettingsSection: some View {
        Section {
            Picker("Match Type", selection: $viewModel.matchType) {
                ForEach(MatchType.availableTypes(for: viewModel.generation), id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Picker("Best Of", selection: $viewModel.bestOf) {
                ForEach(BestOf.allCases, id: \.self) { bestOf in
                    Text(bestOf.displayName).tag(bestOf)
                }
            }

            if viewModel.generation.supportsOwnFinish {
                Toggle("Own Finish Enabled", isOn: $viewModel.ownFinishEnabled)
            }
        } header: {
            Text(viewModel.isMultiStage ? "Preliminary Stage Settings" : "Match Settings")
        } footer: {
            if viewModel.isMultiStage {
                Text("Settings for \(viewModel.preliminaryFormat.displayName) matches before the finals bracket.")
            }
        }
    }

    // MARK: - Finals Settings Section (Multi-Stage Only)

    private var finalsSettingsSection: some View {
        Section {
            Toggle("Use same settings as preliminary", isOn: $viewModel.useSameFinalsSettings)

            if !viewModel.useSameFinalsSettings {
                Picker("Match Type", selection: $viewModel.finalsMatchTypeSelection) {
                    ForEach(MatchType.availableTypes(for: viewModel.generation), id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Picker("Best Of", selection: $viewModel.finalsBestOfSelection) {
                    ForEach(BestOf.allCases, id: \.self) { bestOf in
                        Text(bestOf.displayName).tag(bestOf)
                    }
                }

                if viewModel.generation.supportsOwnFinish {
                    Toggle("Own Finish Enabled", isOn: $viewModel.finalsOwnFinishEnabled)
                }
            }
        } header: {
            Text("Finals Stage Settings")
        } footer: {
            if viewModel.useSameFinalsSettings {
                Text("Finals matches will use the same settings as preliminary stage.")
            }
        }
    }

    // MARK: - Players Section

    private var playersSection: some View {
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
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        Section {
            Toggle("Shuffle Players", isOn: $viewModel.shufflePlayers)
        } header: {
            Text("Options")
        } footer: {
            Text("Randomizes player seeding when creating the bracket.")
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            BracketPreview(
                playerCount: viewModel.players.count,
                numberOfRounds: viewModel.numberOfRounds,
                tournamentType: viewModel.effectiveTournamentType,
                isMultiStage: viewModel.isMultiStage,
                finalsSize: viewModel.finalsSize
            )
        } header: {
            Text("Tournament Summary")
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

    // Stage selection
    @Published var isMultiStage: Bool = false

    // Single stage format
    @Published var tournamentType: TournamentType = .singleElimination

    // Multi-stage formats
    @Published var preliminaryFormat: TournamentType = .swiss
    @Published var finalsType: TournamentType = .singleElimination
    @Published var finalsSize: Int = 8

    // Finals settings
    @Published var useSameFinalsSettings: Bool = true
    @Published var finalsMatchTypeSelection: MatchType = .points4
    @Published var finalsBestOfSelection: BestOf = .none
    @Published var finalsOwnFinishEnabled: Bool = false

    init() {
        regenerateRoomCode()
    }

    /// The effective tournament type based on stage selection.
    var effectiveTournamentType: TournamentType {
        isMultiStage ? preliminaryFormat : tournamentType
    }

    /// Finals match type (nil = same as preliminary).
    var finalsMatchType: MatchType? {
        useSameFinalsSettings ? nil : finalsMatchTypeSelection
    }

    /// Finals best of (nil = same as preliminary).
    var finalsBestOf: BestOf? {
        useSameFinalsSettings ? nil : finalsBestOfSelection
    }

    var canCreateTournament: Bool {
        !tournamentName.trimmingCharacters(in: .whitespaces).isEmpty &&
        players.count >= 2 &&
        roomCode.count == 6 &&
        (!isMultiStage || finalsSize <= players.count)
    }

    /// Number of rounds based on tournament type.
    var numberOfRounds: Int {
        guard players.count > 1 else { return 0 }

        let format = effectiveTournamentType

        switch format {
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
        let format = effectiveTournamentType

        switch format {
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
        let format = effectiveTournamentType

        switch format {
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
        stageConfig.isMultiStage = isMultiStage
        stageConfig.stage1Type = effectiveTournamentType
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
            tournamentType: effectiveTournamentType,
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
