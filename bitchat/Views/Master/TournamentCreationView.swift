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

                // Players Section
                Section {
                    PlayerListEditor(players: $viewModel.players)
                } header: {
                    HStack {
                        Text("Players (\(viewModel.players.count))")
                        Spacer()
                        if viewModel.players.count >= 2 {
                            Text("\(viewModel.numberOfRounds) rounds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Minimum 2 players required. Players are seeded in order (drag to reorder).")
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
                            numberOfRounds: viewModel.numberOfRounds
                        )
                    } header: {
                        Text("Bracket Preview")
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

    init() {
        regenerateRoomCode()
    }

    var canCreateTournament: Bool {
        !tournamentName.trimmingCharacters(in: .whitespaces).isEmpty &&
        players.count >= 2 &&
        roomCode.count == 6
    }

    var numberOfRounds: Int {
        guard players.count > 1 else { return 0 }
        return Int(ceil(log2(Double(players.count))))
    }

    func regenerateRoomCode() {
        roomCode = RoomCode.generate().code
    }

    func createTournament() -> Tournament? {
        guard canCreateTournament else { return nil }

        let filteredPlayers = players.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard filteredPlayers.count >= 2 else { return nil }

        return Tournament.create(
            name: tournamentName.trimmingCharacters(in: .whitespaces),
            roomCode: roomCode,
            players: filteredPlayers,
            generation: generation,
            matchType: matchType,
            bestOf: bestOf,
            ownFinishEnabled: ownFinishEnabled,
            shuffle: shufflePlayers
        )
    }
}

// MARK: - Bracket Preview

struct BracketPreview: View {
    let playerCount: Int
    let numberOfRounds: Int

    private var bracketSize: Int {
        var power = 1
        while power < playerCount {
            power *= 2
        }
        return power
    }

    private var byeCount: Int {
        bracketSize - playerCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(playerCount) players", systemImage: "person.2")
                Spacer()
                Label("\(numberOfRounds) rounds", systemImage: "rectangle.3.group")
            }
            .font(.subheadline)

            HStack {
                Label("\(bracketSize - 1) matches", systemImage: "sportscourt")
                Spacer()
                if byeCount > 0 {
                    Label("\(byeCount) byes", systemImage: "arrow.right.circle")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            // Visual bracket representation
            HStack(spacing: 4) {
                ForEach(1...numberOfRounds, id: \.self) { round in
                    RoundColumn(
                        round: round,
                        matchCount: bracketSize / Int(pow(2.0, Double(round))),
                        isLast: round == numberOfRounds
                    )
                }
            }
            .frame(height: 60)
        }
    }
}

struct RoundColumn: View {
    let round: Int
    let matchCount: Int
    let isLast: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("R\(round)")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 1) {
                ForEach(0..<matchCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isLast ? Color.yellow : Color.blue.opacity(0.5))
                        .frame(width: 8, height: 20)
                }
            }

            Text("\(matchCount)")
                .font(.caption2)
                .foregroundColor(.secondary)
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
