//
// ChallongeImportView.swift
// bitchat
//
// View for importing a tournament from Challonge.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for importing a tournament from Challonge
struct ChallongeImportView: View {
    @StateObject private var viewModel = ChallongeImportViewModel()
    @Environment(\.dismiss) private var dismiss

    let onTournamentImported: (Tournament) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Credentials Section
                if !viewModel.hasCredentials {
                    credentialsSection
                }

                // Tournament URL Section
                tournamentUrlSection

                // Preview Section (after fetch)
                if let preview = viewModel.tournamentPreview {
                    previewSection(preview)
                    // Only show stage picker if NOT auto-detected as multi-stage
                    if !viewModel.isMultiStageDetected {
                        stageTypeSection
                    }
                    formatSelectionSection
                    generationSection
                    matchSettingsSection
                    if viewModel.isMultiStage {
                        finalsMatchSettingsSection
                    }
                    confirmSection
                }

                // Error Display
                if let error = viewModel.error {
                    errorSection(error)
                }

                // API Usage Info
                apiUsageSection

                // Manage Credentials
                if viewModel.hasCredentials {
                    manageCredentialsSection
                }
            }
            .navigationTitle("Import from Challonge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.importedTournament) { tournament in
                if let tournament = tournament {
                    onTournamentImported(tournament)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Credentials Section

    private var credentialsSection: some View {
        Section {
            TextField("Challonge Username", text: $viewModel.username)
                .textContentType(.username)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            SecureField("API Key", text: $viewModel.apiKey)

            Button {
                Task { await viewModel.saveCredentials() }
            } label: {
                if viewModel.isValidatingCredentials {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating...")
                    }
                } else {
                    Text("Save Credentials")
                }
            }
            .disabled(!viewModel.canSaveCredentials || viewModel.isValidatingCredentials)
        } header: {
            Text("Challonge Credentials")
        } footer: {
            Text("Find your API key at challonge.com/settings/developer")
        }
    }

    // MARK: - Tournament URL Section

    private var tournamentUrlSection: some View {
        Section {
            TextField("Tournament URL or ID", text: $viewModel.tournamentUrl)
                .textContentType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .disabled(!viewModel.hasCredentials)

            Button {
                Task { await viewModel.fetchPreview() }
            } label: {
                if viewModel.isLoading && viewModel.tournamentPreview == nil {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Fetching...")
                    }
                } else {
                    Text("Fetch Tournament")
                }
            }
            .disabled(!viewModel.canFetchPreview)
        } header: {
            Text("Import Tournament")
        } footer: {
            Text("Paste the full Challonge URL (e.g., challonge.com/mytournament) or just the tournament ID")
        }
    }

    // MARK: - Preview Section

    private func previewSection(_ preview: ChallongeImportPreview) -> some View {
        Section {
            LabeledContent("Name", value: preview.name)
            LabeledContent("Players", value: "\(preview.playerCount)")
            LabeledContent("Status", value: preview.status)

            // Only show match count if there are matches available
            if preview.matchCount > 0 {
                LabeledContent("Matches available", value: "\(preview.matchCount)")
            }

            // Show auto-detected multi-stage status
            if preview.hasGroupStages {
                Label("Multi-stage tournament detected", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        } header: {
            Text("Tournament Preview")
        } footer: {
            if preview.hasGroupStages {
                Text("Multi-stage structure detected from Challonge")
            } else {
                Text("Configure the tournament format below")
            }
        }
    }

    // MARK: - Stage Type Section

    private var stageTypeSection: some View {
        Section {
            Picker("Structure", selection: $viewModel.isMultiStage) {
                Text("Single Stage").tag(false)
                Text("Multi-Stage (Prelim + Finals)").tag(true)
            }
        } header: {
            Text("Tournament Structure")
        } footer: {
            if viewModel.isMultiStage {
                Text("Multi-stage tournaments have a preliminary stage (Swiss/Round Robin) followed by a finals bracket")
            } else {
                Text("Single stage tournaments run one format throughout")
            }
        }
    }

    // MARK: - Format Selection Section

    @ViewBuilder
    private var formatSelectionSection: some View {
        if viewModel.isMultiStage {
            // Multi-stage: separate preliminary and finals format pickers
            Section {
                Picker("Preliminary Format", selection: $viewModel.preliminaryFormat) {
                    Text("Swiss").tag(TournamentType.swiss)
                    Text("Round Robin").tag(TournamentType.roundRobin)
                }
            } header: {
                Text("Preliminary Stage")
            }

            Section {
                Picker("Finals Format", selection: $viewModel.finalsFormat) {
                    Text("Single Elimination").tag(TournamentType.singleElimination)
                    Text("Double Elimination").tag(TournamentType.doubleElimination)
                }
            } header: {
                Text("Finals Stage")
            }
        } else {
            // Single stage: one format picker
            Section {
                Picker("Format", selection: $viewModel.singleStageFormat) {
                    Text("Single Elimination").tag(TournamentType.singleElimination)
                    Text("Double Elimination").tag(TournamentType.doubleElimination)
                    Text("Round Robin").tag(TournamentType.roundRobin)
                    Text("Swiss").tag(TournamentType.swiss)
                }
            } header: {
                Text("Tournament Format")
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
            Text("Beyblade Generation")
        } footer: {
            Text("Generation applies to all matches in the tournament")
        }
    }

    // MARK: - Match Settings Section

    private var matchSettingsSection: some View {
        Section {
            Picker("Match Type", selection: $viewModel.matchType) {
                ForEach(viewModel.tournamentMatchTypes, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Picker("Best Of", selection: $viewModel.bestOf) {
                ForEach(BestOf.allCases, id: \.self) { bo in
                    Text(bo.displayName).tag(bo)
                }
            }

            if viewModel.generation.supportsOwnFinish {
                Toggle("Own Finish Enabled", isOn: $viewModel.ownFinishEnabled)
            }
        } header: {
            if viewModel.isMultiStage {
                Text("Preliminary Stage Settings")
            } else {
                Text("Match Settings")
            }
        } footer: {
            if viewModel.isMultiStage {
                Text("These settings apply to preliminary stage matches")
            } else {
                Text("These settings apply to all matches scored in BeyScore")
            }
        }
    }

    // MARK: - Finals Match Settings Section

    @ViewBuilder
    private var finalsMatchSettingsSection: some View {
        Section {
            Toggle("Use same settings as preliminary", isOn: $viewModel.useSameSettingsForFinals)
        }

        if !viewModel.useSameSettingsForFinals {
            Section {
                Picker("Match Type", selection: $viewModel.finalsMatchType) {
                    ForEach(viewModel.tournamentMatchTypes, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Picker("Best Of", selection: $viewModel.finalsBestOf) {
                    ForEach(BestOf.allCases, id: \.self) { bo in
                        Text(bo.displayName).tag(bo)
                    }
                }

                if viewModel.generation.supportsOwnFinish {
                    Toggle("Own Finish Enabled", isOn: $viewModel.finalsOwnFinishEnabled)
                }
            } header: {
                Text("Finals Stage Settings")
            } footer: {
                Text("These settings apply to finals bracket matches")
            }
        }
    }

    // MARK: - Confirm Section

    private var confirmSection: some View {
        Section {
            Button {
                viewModel.confirmImport()
            } label: {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Importing...")
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        Label("Create Tournament", systemImage: "plus.circle.fill")
                        Spacer()
                    }
                }
            }
            .disabled(!viewModel.canImport)
        }
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        Section {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }

    // MARK: - API Usage Section

    private var apiUsageSection: some View {
        Section {
            HStack {
                Text("API Calls Remaining")
                Spacer()
                Text("\(viewModel.remainingApiCalls) / 500")
                    .foregroundColor(viewModel.isApproachingLimit ? .orange : .secondary)
            }

            if viewModel.isApproachingLimit {
                Label("Approaching monthly limit", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        } header: {
            Text("API Usage")
        } footer: {
            Text("Challonge allows 500 free API calls per month")
        }
    }

    // MARK: - Manage Credentials Section

    private var manageCredentialsSection: some View {
        Section {
            Button("Clear Saved Credentials", role: .destructive) {
                viewModel.clearCredentials()
            }
        }
    }
}

#Preview {
    ChallongeImportView { tournament in
        print("Imported: \(tournament.name)")
    }
}
