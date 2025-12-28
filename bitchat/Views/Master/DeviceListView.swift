//
// DeviceListView.swift
// bitchat
//
// Connected scoreboard devices list for Master mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// List of connected scoreboard devices.
struct DeviceListView: View {
    @ObservedObject var tournamentManager: TournamentManager
    let onDeviceSelected: ((ConnectedScoreboard) -> Void)?

    @State private var selectedDeviceId: String?

    init(
        tournamentManager: TournamentManager = .shared,
        onDeviceSelected: ((ConnectedScoreboard) -> Void)? = nil
    ) {
        self.tournamentManager = tournamentManager
        self.onDeviceSelected = onDeviceSelected
    }

    var body: some View {
        List {
            if tournamentManager.connectedScoreboards.isEmpty {
                EmptyDevicesView()
            } else {
                // Available devices
                if !tournamentManager.availableScoreboards.isEmpty {
                    Section {
                        ForEach(tournamentManager.availableScoreboards) { device in
                            DeviceRow(
                                device: device,
                                currentMatch: nil,
                                isSelected: selectedDeviceId == device.id,
                                onTap: {
                                    selectedDeviceId = device.id
                                    onDeviceSelected?(device)
                                }
                            )
                        }
                    } header: {
                        Label("Available", systemImage: "checkmark.circle")
                    }
                }

                // Busy devices
                let busyDevices = tournamentManager.connectedScoreboards.filter { $0.status != .idle }
                if !busyDevices.isEmpty {
                    Section {
                        ForEach(busyDevices) { device in
                            let match = device.currentMatchId.flatMap { id in
                                tournamentManager.currentTournament?.match(byId: id)
                            }
                            DeviceRow(
                                device: device,
                                currentMatch: match,
                                isSelected: selectedDeviceId == device.id,
                                onTap: {
                                    selectedDeviceId = device.id
                                    onDeviceSelected?(device)
                                }
                            )
                        }
                    } header: {
                        Label("In Use", systemImage: "play.circle")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: ConnectedScoreboard
    let currentMatch: TournamentMatch?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: deviceIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 36)

                // Device info
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.deviceName)
                        .font(.body)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        DeviceStatusBadge(status: device.status)

                        if let match = currentMatch {
                            Text(match.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Last seen indicator
                if device.status == .idle {
                    Text(timeAgo(device.lastSeen))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }

    private var deviceIcon: String {
        switch device.status {
        case .idle:
            return "ipad.landscape"
        case .matchAssigned:
            return "ipad.landscape.badge.play"
        case .scoring:
            return "sportscourt"
        case .awaitingApproval:
            return "clock.badge.questionmark"
        }
    }

    private var statusColor: Color {
        switch device.status {
        case .idle: return .secondary
        case .matchAssigned: return .blue
        case .scoring: return .green
        case .awaitingApproval: return .orange
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}

// MARK: - Device Status Badge

struct DeviceStatusBadge: View {
    let status: ScoreboardStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .idle: return Color(.systemGray5)
        case .matchAssigned: return Color.blue.opacity(0.2)
        case .scoring: return Color.green.opacity(0.2)
        case .awaitingApproval: return Color.orange.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .idle: return .secondary
        case .matchAssigned: return .blue
        case .scoring: return .green
        case .awaitingApproval: return .orange
        }
    }
}

// MARK: - Empty Devices View

struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ipad.landscape")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Scoreboards Connected")
                .font(.headline)

            Text("Scoreboards will appear here when they join the tournament room.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Compact Device List (for sidebar)

struct CompactDeviceList: View {
    @ObservedObject var tournamentManager: TournamentManager

    init(tournamentManager: TournamentManager = .shared) {
        self.tournamentManager = tournamentManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scoreboards")
                    .font(.headline)

                Spacer()

                Text("\(tournamentManager.connectedScoreboards.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if tournamentManager.connectedScoreboards.isEmpty {
                Text("No devices connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(tournamentManager.connectedScoreboards.prefix(5)) { device in
                    HStack {
                        Circle()
                            .fill(statusColor(for: device.status))
                            .frame(width: 8, height: 8)

                        Text(device.deviceName)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Text(device.status.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if tournamentManager.connectedScoreboards.count > 5 {
                    Text("+ \(tournamentManager.connectedScoreboards.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func statusColor(for status: ScoreboardStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .matchAssigned: return .blue
        case .scoring: return .green
        case .awaitingApproval: return .orange
        }
    }
}

#Preview {
    DeviceListView()
}
