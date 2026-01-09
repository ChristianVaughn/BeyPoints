//
// ConflictListView.swift
// bitchat
//
// View for displaying and resolving Challonge data conflicts.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for displaying and resolving Challonge data conflicts
struct ConflictListView: View {
    @ObservedObject var syncManager = ChallongeSyncManager.shared
    @Environment(\.dismiss) private var dismiss

    var unresolvedConflicts: [MatchConflict] {
        syncManager.conflicts.filter { !$0.resolved }
    }

    var resolvedConflicts: [MatchConflict] {
        syncManager.conflicts.filter { $0.resolved }
    }

    var body: some View {
        List {
            if unresolvedConflicts.isEmpty && resolvedConflicts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Conflicts")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Local data matches Challonge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Unresolved conflicts
                if !unresolvedConflicts.isEmpty {
                    Section {
                        ForEach(unresolvedConflicts) { conflict in
                            ConflictRow(conflict: conflict) { resolution in
                                syncManager.resolveConflict(conflict, resolution: resolution)
                            }
                        }
                    } header: {
                        Text("Unresolved (\(unresolvedConflicts.count))")
                    } footer: {
                        Text("You'll need to manually update Challonge with the correct data")
                    }
                }

                // Resolved conflicts
                if !resolvedConflicts.isEmpty {
                    Section {
                        ForEach(resolvedConflicts) { conflict in
                            ResolvedConflictRow(conflict: conflict)
                        }
                    } header: {
                        Text("Resolved (\(resolvedConflicts.count))")
                    }
                }
            }
        }
        .navigationTitle("Data Conflicts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

/// Row showing an unresolved conflict with resolution buttons
struct ConflictRow: View {
    let conflict: MatchConflict
    let onResolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Conflict Type Header
            HStack {
                Image(systemName: conflict.conflictType.iconName)
                    .foregroundColor(.orange)
                Text(conflict.conflictType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Values Comparison
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(conflict.localValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }

                Spacer()

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Challonge")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(conflict.challongeValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)

            // Resolution Buttons
            HStack(spacing: 12) {
                Button {
                    onResolve(.keepLocal)
                } label: {
                    Label("Keep Local", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    onResolve(.ignored)
                } label: {
                    Label("Ignore", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Note
            Text("Update Challonge manually after resolving")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Row showing a resolved conflict
struct ResolvedConflictRow: View {
    let conflict: MatchConflict

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(conflict.conflictType.displayName)
                    .font(.subheadline)

                if let resolution = conflict.resolution {
                    Text(resolution.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

#Preview {
    NavigationStack {
        ConflictListView()
    }
}
