//
// MatchDetailSheet.swift
// bitchat
//
// Bottom sheet showing match details with contextual actions.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Bottom sheet for viewing match details and performing actions based on match status.
struct MatchDetailSheet: View {
    let match: TournamentMatch
    let tournament: Tournament
    @ObservedObject var tournamentManager: TournamentManager
    @ObservedObject var messageHandler: TournamentMessageHandler
    @ObservedObject var syncManager = ChallongeSyncManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showUnassignConfirmation = false
    @State private var showChallongeConfirmation = false
    @State private var challongeSubmitError: String?

    init(
        match: TournamentMatch,
        tournament: Tournament,
        tournamentManager: TournamentManager,
        messageHandler: TournamentMessageHandler
    ) {
        self.match = match
        self.tournament = tournament
        self.tournamentManager = tournamentManager
        self.messageHandler = messageHandler
    }

    @MainActor
    init(match: TournamentMatch, tournament: Tournament) {
        self.match = match
        self.tournament = tournament
        self.tournamentManager = .shared
        self.messageHandler = .shared
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status badge
                    statusBadge

                    // Players section
                    playersSection

                    Divider()

                    // Status-specific content
                    statusContent
                }
                .padding()
            }
            .navigationTitle(match.longDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Unassign Match?", isPresented: $showUnassignConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unassign", role: .destructive) {
                unassignMatch()
                dismiss()
            }
        } message: {
            Text("This will unassign the match from its current scoreboard.")
        }
        .alert("Submit to Challonge?", isPresented: $showChallongeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Submit") {
                approveAndSubmitToChallonge()
            }
        } message: {
            if let submission = pendingSubmission {
                Text("Match: \(match.player1Name ?? "P1") vs \(match.player2Name ?? "P2")\nWinner: \(submission.winner)\nScore: \(formatScoreForDisplay(submission))\n\nThis will update the result on Challonge.")
            } else {
                Text("This will update the match result on Challonge.")
            }
        }
        .alert("Challonge Sync Error", isPresented: .init(
            get: { challongeSubmitError != nil },
            set: { if !$0 { challongeSubmitError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = challongeSubmitError {
                Text(error)
            }
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            Text(match.status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(16)
    }

    private var statusIcon: String {
        switch match.status {
        case .pending: return match.isReady ? "clock" : "hourglass"
        case .assigned: return "ipad.landscape"
        case .inProgress: return "play.fill"
        case .awaitingApproval: return "checkmark.circle"
        case .complete: return "trophy.fill"
        }
    }

    private var statusColor: Color {
        switch match.status {
        case .pending: return match.isReady ? .blue : .secondary
        case .assigned: return .blue
        case .inProgress: return .green
        case .awaitingApproval: return .orange
        case .complete: return .green
        }
    }

    // MARK: - Players Section

    /// Get the pending submission for this match if it exists
    private var pendingSubmission: PendingScoreSubmission? {
        tournamentManager.pendingSubmissions.first(where: { $0.matchId == match.id })
    }

    private var playersSection: some View {
        // For awaiting approval, use submission's scores/set wins (match values are still 0)
        let submission = pendingSubmission
        let p1Score = submission?.player1FinalScore ?? match.player1Score
        let p2Score = submission?.player2FinalScore ?? match.player2Score
        let p1SetWins = submission?.player1SetWins ?? match.player1SetWins
        let p2SetWins = submission?.player2SetWins ?? match.player2SetWins
        let winner = submission?.winner ?? match.winner
        let isBestOf = p1SetWins > 0 || p2SetWins > 0

        return VStack(spacing: 16) {
            // Player 1
            playerRow(
                name: match.player1Name,
                score: p1Score,
                setWins: p1SetWins,
                isBestOf: isBestOf,
                isWinner: winner == match.player1Name,
                color: .player1Blue
            )

            Text("vs")
                .font(.caption)
                .foregroundColor(.secondary)

            // Player 2
            playerRow(
                name: match.player2Name,
                score: p2Score,
                setWins: p2SetWins,
                isBestOf: isBestOf,
                isWinner: winner == match.player2Name,
                color: .player2Red
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func playerRow(name: String?, score: Int, setWins: Int, isBestOf: Bool, isWinner: Bool, color: Color) -> some View {
        HStack {
            // Player name
            Text(name ?? "TBD")
                .font(.headline)
                .fontWeight(isWinner ? .bold : .regular)
                .foregroundColor(name == nil ? .secondary : .primary)

            Spacer()

            // Score (if match has started)
            if match.status == .inProgress || match.status == .awaitingApproval || match.status == .complete {
                if isBestOf {
                    // Show set wins for best-of matches
                    Text("\(setWins)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                } else {
                    // Show points
                    Text("\(score)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }

            // Winner indicator
            if isWinner {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
            }
        }
    }

    // MARK: - Status-Specific Content

    @ViewBuilder
    private var statusContent: some View {
        switch match.status {
        case .pending:
            if match.isReady {
                pendingReadyContent
            } else {
                pendingNotReadyContent
            }
        case .assigned, .inProgress:
            assignedContent
        case .awaitingApproval:
            awaitingApprovalContent
        case .complete:
            completeContent
        }
    }

    // MARK: - Pending (Not Ready)

    private var pendingNotReadyContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("Waiting for Players")
                .font(.headline)

            Text("This match is waiting for previous matches to complete before players are determined.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Pending (Ready to Assign)

    private var pendingReadyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assign to Scoreboard")
                .font(.headline)

            if tournamentManager.availableScoreboards.isEmpty {
                HStack {
                    Image(systemName: "ipad.slash")
                        .foregroundColor(.secondary)
                    Text("No available scoreboards")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(tournamentManager.availableScoreboards) { device in
                        Button {
                            assignToDevice(device)
                        } label: {
                            HStack {
                                Image(systemName: "ipad.landscape")
                                    .font(.title3)

                                VStack(alignment: .leading) {
                                    Text(device.deviceName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Tap to assign")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Assigned / In Progress

    private var assignedContent: some View {
        VStack(spacing: 16) {
            // Device info
            if let deviceId = match.assignedDeviceId,
               let device = tournamentManager.connectedScoreboards.first(where: { $0.id == deviceId }) {
                HStack {
                    Image(systemName: "ipad.landscape")
                        .font(.title2)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading) {
                        Text(device.deviceName)
                            .font(.headline)
                        Text(device.status.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(match.status == .inProgress ? Color.green : Color.blue)
                        .frame(width: 10, height: 10)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }

            // Action buttons
            VStack(spacing: 12) {
                // Reassign button
                Button {
                    // Unassign first, then the view will update to show assignment options
                    unassignMatch()
                } label: {
                    Label("Reassign to Different Scoreboard", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Unassign button
                Button(role: .destructive) {
                    showUnassignConfirmation = true
                } label: {
                    Label("Unassign Match", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Awaiting Approval

    private var awaitingApprovalContent: some View {
        VStack(spacing: 16) {
            // Score preview
            if let submission = tournamentManager.pendingSubmissions.first(where: { $0.matchId == match.id }) {
                let isBestOf = submission.player1SetWins > 0 || submission.player2SetWins > 0

                VStack(spacing: 8) {
                    Text("Submitted Score")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        // Show set wins for best-of, otherwise final scores
                        Text("\(isBestOf ? submission.player1SetWins : submission.player1FinalScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.player1Blue)

                        Text("-")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("\(isBestOf ? submission.player2SetWins : submission.player2FinalScore)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.player2Red)
                    }

                    if isBestOf {
                        Text("Sets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("\(submission.winner) wins")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                // Approval buttons
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        messageHandler.rejectScore(matchId: match.id, reason: nil)
                        dismiss()
                    } label: {
                        Label("Reject", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        handleApprove()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text(syncManager.isLinked ? "Approve & Sync" : "Approve")
                            if syncManager.isLinked {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Match history
                if !submission.matchHistory.isEmpty {
                    DisclosureGroup("Match History") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(submission.matchHistory.enumerated()), id: \.offset) { index, entry in
                                if entry.isGameDivider {
                                    Divider()
                                        .padding(.vertical, 4)
                                } else {
                                    HStack {
                                        Text(entry.player == .player1 ? (match.player1Name ?? "P1") : (match.player2Name ?? "P2"))
                                            .font(.caption)
                                            .frame(width: 80, alignment: .leading)

                                        Text(entry.condition.chipLabel)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(entry.condition.chipColor.opacity(0.2))
                                            .foregroundColor(entry.condition.chipColor)
                                            .cornerRadius(4)

                                        Spacer()

                                        Text("\(entry.score1After) - \(entry.score2After)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: - Complete

    private var completeContent: some View {
        VStack(spacing: 16) {
            // Winner announcement
            if let winner = match.winner {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundColor(.yellow)

                    Text("\(winner) wins!")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(10)
            }

            // Final score
            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if match.player1SetWins > 0 || match.player2SetWins > 0 {
                    // Best-of match - show set wins
                    Text("\(match.player1SetWins) - \(match.player2SetWins)")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Single game - show points
                    Text("\(match.player1Score) - \(match.player2Score)")
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            // Match history (if available)
            if !match.matchHistory.isEmpty {
                DisclosureGroup("Match History") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(match.matchHistory.enumerated()), id: \.offset) { index, entry in
                            if entry.isGameDivider {
                                Divider()
                                    .padding(.vertical, 4)
                            } else {
                                HStack {
                                    Text(entry.player == .player1 ? (match.player1Name ?? "P1") : (match.player2Name ?? "P2"))
                                        .font(.caption)
                                        .frame(width: 80, alignment: .leading)

                                    Text(entry.condition.chipLabel)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(entry.condition.chipColor.opacity(0.2))
                                        .foregroundColor(entry.condition.chipColor)
                                        .cornerRadius(4)

                                    Spacer()

                                    Text("\(entry.score1After) - \(entry.score2After)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Actions

    private func assignToDevice(_ device: ConnectedScoreboard) {
        tournamentManager.assignMatch(matchId: match.id, to: device.id)

        let config = tournament.createMatchConfiguration(for: match)
        messageHandler.assignMatchToDevice(
            match: match,
            deviceId: device.id,
            config: config
        )

        dismiss()
    }

    private func unassignMatch() {
        MatchAssignmentService.shared.cancelAssignment(matchId: match.id)
    }

    private func handleApprove() {
        if syncManager.isLinked {
            showChallongeConfirmation = true
        } else {
            messageHandler.approveScore(matchId: match.id)
            dismiss()
        }
    }

    private func approveAndSubmitToChallonge() {
        guard let submission = pendingSubmission else {
            messageHandler.approveScore(matchId: match.id)
            dismiss()
            return
        }

        // Approve locally first
        messageHandler.approveScore(matchId: match.id)

        // Determine if this is a Best Of match
        let isBestOf = submission.player1SetWins > 0 || submission.player2SetWins > 0

        // Submit to Challonge in background
        Task {
            do {
                try await syncManager.submitScoreToChallonge(
                    matchId: submission.matchId,
                    winner: submission.winner,
                    player1Score: submission.player1FinalScore,
                    player2Score: submission.player2FinalScore,
                    player1SetWins: submission.player1SetWins,
                    player2SetWins: submission.player2SetWins,
                    isBestOf: isBestOf
                )
            } catch {
                challongeSubmitError = "Score approved locally but failed to sync to Challonge after 3 attempts. Please update the match manually on Challonge."
            }
        }

        dismiss()
    }

    private func formatScoreForDisplay(_ submission: PendingScoreSubmission) -> String {
        if submission.player1SetWins > 0 || submission.player2SetWins > 0 {
            return "\(submission.player1SetWins)-\(submission.player2SetWins)"
        } else {
            return "\(submission.player1FinalScore)-\(submission.player2FinalScore)"
        }
    }
}

#Preview {
    let tournament = Tournament.create(
        name: "Test Tournament",
        roomCode: "123456",
        players: ["Alice", "Bob", "Charlie", "Dave"],
        shuffle: false
    )

    return Text("Preview")
        .sheet(isPresented: .constant(true)) {
            MatchDetailSheet(
                match: tournament.matches.first ?? TournamentMatch(
                    roundNumber: 1,
                    matchNumber: 0,
                    player1Name: "Alice",
                    player2Name: "Bob"
                ),
                tournament: tournament
            )
        }
}
