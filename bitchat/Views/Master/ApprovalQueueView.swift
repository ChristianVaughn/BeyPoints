//
// ApprovalQueueView.swift
// bitchat
//
// Score approval queue for reviewing pending match submissions.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Queue of pending score submissions awaiting Master approval.
struct ApprovalQueueView: View {
    @ObservedObject var tournamentManager: TournamentManager
    @ObservedObject var messageHandler: TournamentMessageHandler
    @State private var selectedSubmission: PendingScoreSubmission?
    @State private var showingRejectSheet = false
    @State private var rejectionReason = ""

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
        Group {
            if tournamentManager.pendingSubmissions.isEmpty {
                EmptyApprovalQueueView()
            } else {
                List {
                    ForEach(tournamentManager.pendingSubmissions) { submission in
                        ApprovalCard(
                            submission: submission,
                            tournament: tournamentManager.currentTournament,
                            onApprove: {
                                messageHandler.approveScore(matchId: submission.matchId)
                            },
                            onReject: {
                                selectedSubmission = submission
                                showingRejectSheet = true
                            }
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(isPresented: $showingRejectSheet) {
            RejectScoreSheet(
                submission: selectedSubmission,
                tournament: tournamentManager.currentTournament,
                reason: $rejectionReason,
                onReject: {
                    if let submission = selectedSubmission {
                        messageHandler.rejectScore(
                            matchId: submission.matchId,
                            reason: rejectionReason.isEmpty ? nil : rejectionReason
                        )
                    }
                    showingRejectSheet = false
                    rejectionReason = ""
                    selectedSubmission = nil
                },
                onCancel: {
                    showingRejectSheet = false
                    rejectionReason = ""
                    selectedSubmission = nil
                }
            )
        }
    }
}

// MARK: - Approval Card

struct ApprovalCard: View {
    let submission: PendingScoreSubmission
    let tournament: Tournament?
    let onApprove: () -> Void
    let onReject: () -> Void

    private var match: TournamentMatch? {
        tournament?.match(byId: submission.matchId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let match = match {
                    Text(match.longDisplayName)
                        .font(.headline)
                } else {
                    Text("Match")
                        .font(.headline)
                }

                Spacer()

                Text(timeAgo(submission.submittedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Match result - show set wins for best-of, points otherwise
            HStack(spacing: 0) {
                // Player 1
                VStack(spacing: 4) {
                    Text(match?.player1Name ?? "Player 1")
                        .font(.subheadline)
                        .fontWeight(submission.winner == match?.player1Name ? .bold : .regular)

                    // Show set wins if this was a best-of match, otherwise show points
                    if submission.player1SetWins > 0 || submission.player2SetWins > 0 {
                        Text("\(submission.player1SetWins)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(submission.winner == match?.player1Name ? .green : .primary)
                    } else {
                        Text("\(submission.player1FinalScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(submission.winner == match?.player1Name ? .green : .primary)
                    }
                }
                .frame(maxWidth: .infinity)

                // VS
                Text("vs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Player 2
                VStack(spacing: 4) {
                    Text(match?.player2Name ?? "Player 2")
                        .font(.subheadline)
                        .fontWeight(submission.winner == match?.player2Name ? .bold : .regular)

                    // Show set wins if this was a best-of match, otherwise show points
                    if submission.player1SetWins > 0 || submission.player2SetWins > 0 {
                        Text("\(submission.player2SetWins)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(submission.winner == match?.player2Name ? .green : .primary)
                    } else {
                        Text("\(submission.player2FinalScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(submission.winner == match?.player2Name ? .green : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Winner announcement
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)

                Text("\(submission.winner) wins!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

            // History preview
            if !submission.matchHistory.isEmpty {
                HistoryPreview(history: submission.matchHistory, match: match)
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onReject()
                } label: {
                    Label("Reject", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onApprove()
                } label: {
                    Label("Approve", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}

// MARK: - History Preview

struct HistoryPreview: View {
    let history: [HistoryEntry]
    let match: TournamentMatch?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Match History")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(history.enumerated()), id: \.offset) { index, entry in
                        if entry.isGameDivider {
                            Divider()
                                .padding(.vertical, 4)
                        } else {
                            HistoryEntryRow(
                                entry: entry,
                                player1Name: match?.player1Name ?? "P1",
                                player2Name: match?.player2Name ?? "P2"
                            )
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct HistoryEntryRow: View {
    let entry: HistoryEntry
    let player1Name: String
    let player2Name: String

    var body: some View {
        HStack(spacing: 8) {
            // Player indicator
            Text(entry.player == .player1 ? player1Name : player2Name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Condition
            Text(entry.condition.chipLabel)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(conditionColor.opacity(0.2))
                .foregroundColor(conditionColor)
                .cornerRadius(2)

            Spacer()

            // Score after
            Text("\(entry.score1After) - \(entry.score2After)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var conditionColor: Color {
        switch entry.condition {
        case .xtreme: return .purple
        case .burst: return .red
        case .over: return .blue
        case .spin: return .yellow
        case .penalty: return .red
        case .ownFinish: return .orange
        }
    }
}

// MARK: - Reject Score Sheet

struct RejectScoreSheet: View {
    let submission: PendingScoreSubmission?
    let tournament: Tournament?
    @Binding var reason: String
    let onReject: () -> Void
    let onCancel: () -> Void

    private var match: TournamentMatch? {
        guard let submission = submission else { return nil }
        return tournament?.match(byId: submission.matchId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let match = match, let submission = submission {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(match.longDisplayName)
                                .font(.headline)

                            HStack {
                                Text("\(match.player1Name ?? "P1") \(submission.player1FinalScore) - \(submission.player2FinalScore) \(match.player2Name ?? "P2")")
                                    .font(.subheadline)
                            }

                            Text("Winner: \(submission.winner)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Match to Reject")
                }

                Section {
                    TextField("Reason (optional)", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Rejection Reason")
                } footer: {
                    Text("The scoreboard will be notified and can re-score the match.")
                }
            }
            .navigationTitle("Reject Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Reject", role: .destructive) {
                        onReject()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Empty Queue View

struct EmptyApprovalQueueView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Pending Approvals")
                .font(.headline)

            Text("Score submissions from scoreboards will appear here for your review.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Approval Badge (for navigation)

struct ApprovalBadge: View {
    @ObservedObject var tournamentManager: TournamentManager

    init(tournamentManager: TournamentManager) {
        self.tournamentManager = tournamentManager
    }

    @MainActor
    init() {
        self.tournamentManager = .shared
    }

    var body: some View {
        if tournamentManager.hasPendingSubmissions {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle")

                Text("\(tournamentManager.pendingSubmissions.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        } else {
            Image(systemName: "checkmark.circle")
        }
    }
}

#Preview {
    NavigationStack {
        ApprovalQueueView()
            .navigationTitle("Approvals")
    }
}
