//
// ChallongeSyncStatusView.swift
// bitchat
//
// View showing Challonge sync status and manual refresh button.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View showing Challonge sync status
struct ChallongeSyncStatusView: View {
    @ObservedObject var syncManager = ChallongeSyncManager.shared
    @State private var showConflicts = false

    var body: some View {
        if let syncState = syncManager.syncState {
            VStack(spacing: 12) {
                // Status Header
                HStack {
                    Image(systemName: syncState.syncStatus.iconName)
                        .foregroundColor(statusColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncState.syncStatus.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Last synced: \(syncState.lastSyncedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if syncManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                // Conflicts Alert
                if !syncManager.conflicts.filter({ !$0.resolved }).isEmpty {
                    Button {
                        showConflicts = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("\(syncManager.conflicts.filter { !$0.resolved }.count) conflict(s) detected")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(10)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // New Matches Alert
                if syncManager.newMatchCount > 0 {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("\(syncManager.newMatchCount) new match(es) imported")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(10)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                }

                // API Usage Warning
                if syncManager.isApproachingLimit {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Approaching API limit (\(syncManager.remainingApiCalls) calls left)")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }

                // Manual Refresh Button
                Button {
                    Task {
                        do {
                            try await syncManager.refresh()
                        } catch {
                            // Error is captured in syncManager.lastError
                        }
                    }
                } label: {
                    Label("Refresh from Challonge", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(syncManager.isSyncing)

                // Error Display
                if let error = syncManager.lastError {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text(error.localizedDescription)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .sheet(isPresented: $showConflicts) {
                NavigationStack {
                    ConflictListView()
                }
            }
        }
    }

    private var statusColor: Color {
        switch syncManager.syncState?.syncStatus {
        case .synced: return .green
        case .hasConflicts: return .orange
        case .newMatchesAvailable: return .blue
        case .syncError: return .red
        default: return .gray
        }
    }
}

#Preview {
    VStack {
        ChallongeSyncStatusView()
        Spacer()
    }
    .padding()
}
