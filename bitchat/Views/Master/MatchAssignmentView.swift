//
// MatchAssignmentView.swift
// bitchat
//
// Match assignment interface for assigning matches to scoreboards.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for assigning matches to scoreboard devices.
struct MatchAssignmentView: View {
    @ObservedObject var tournamentManager: TournamentManager
    @ObservedObject var messageHandler: TournamentMessageHandler
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMatch: TournamentMatch?
    @State private var selectedDevice: ConnectedScoreboard?

    init(
        tournamentManager: TournamentManager,
        messageHandler: TournamentMessageHandler
    ) {
        self.tournamentManager = tournamentManager
        self.messageHandler = messageHandler
    }

    @MainActor
    init() {
        self.tournamentManager = .shared
        self.messageHandler = .shared
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Match selection
                MatchSelectionSection(
                    matches: tournamentManager.assignableMatches,
                    selectedMatch: $selectedMatch
                )

                Divider()

                // Device selection
                DeviceSelectionSection(
                    devices: tournamentManager.availableScoreboards,
                    selectedDevice: $selectedDevice
                )

                Divider()

                // Action button
                AssignmentActionButton(
                    canAssign: canAssign,
                    onAssign: assignMatch
                )
            }
            .navigationTitle("Assign Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canAssign: Bool {
        selectedMatch != nil && selectedDevice != nil
    }

    private func assignMatch() {
        guard let match = selectedMatch,
              let device = selectedDevice,
              let tournament = tournamentManager.currentTournament else { return }

        // Update local state
        tournamentManager.assignMatch(matchId: match.id, to: device.id)

        // Send assignment message to scoreboard
        let config = tournament.createMatchConfiguration(for: match)
        messageHandler.assignMatchToDevice(
            match: match,
            deviceId: device.id,
            config: config
        )

        dismiss()
    }
}

// MARK: - Match Selection Section

struct MatchSelectionSection: View {
    let matches: [TournamentMatch]
    @Binding var selectedMatch: TournamentMatch?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Match")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if matches.isEmpty {
                EmptyMatchesView()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matches) { match in
                            MatchSelectionCard(
                                match: match,
                                isSelected: selectedMatch?.id == match.id
                            ) {
                                selectedMatch = match
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(height: 180)
    }
}

struct MatchSelectionCard: View {
    let match: TournamentMatch
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Match info header
                HStack {
                    Text(match.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }

                Divider()

                // Player 1
                HStack {
                    Text(match.player1Name ?? "TBD")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()
                }

                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Player 2
                HStack {
                    Text(match.player2Name ?? "TBD")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()
                }
            }
            .padding()
            .frame(width: 160)
            .background(isSelected ? Color.selectionBackground(for: colorScheme) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBlue(for: colorScheme) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmptyMatchesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(.secondary)

            Text("No matches available")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("All matches are assigned or completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Device Selection Section

struct DeviceSelectionSection: View {
    let devices: [ConnectedScoreboard]
    @Binding var selectedDevice: ConnectedScoreboard?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Scoreboard")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if devices.isEmpty {
                EmptyDevicesSelectionView()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(devices) { device in
                            DeviceSelectionCard(
                                device: device,
                                isSelected: selectedDevice?.id == device.id
                            ) {
                                selectedDevice = device
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(height: 140)
    }
}

struct DeviceSelectionCard: View {
    let device: ConnectedScoreboard
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: "ipad.landscape")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)

                Text(device.deviceName)
                    .font(.subheadline)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding()
            .frame(width: 120)
            .background(isSelected ? Color.selectionBackground(for: colorScheme) : Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBlue(for: colorScheme) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EmptyDevicesSelectionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "ipad.landscape")
                .font(.title)
                .foregroundColor(.secondary)

            Text("No scoreboards available")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("All scoreboards are busy")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Assignment Action Button

struct AssignmentActionButton: View {
    let canAssign: Bool
    let onAssign: () -> Void

    var body: some View {
        Button(action: onAssign) {
            Label("Assign Match", systemImage: "arrow.right.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canAssign)
        .padding()
    }
}

#Preview {
    MatchAssignmentView()
}
