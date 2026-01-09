//
// ChallongeImportViewModel.swift
// bitchat
//
// ViewModel for Challonge import flow.
// Part of BeyScore Tournament System.
//

import Foundation
import SwiftUI

/// ViewModel for the Challonge import flow
@MainActor
final class ChallongeImportViewModel: ObservableObject {

    // MARK: - Tournament Import

    @Published var tournamentUrl = ""
    @Published var tournamentPreview: ChallongeImportPreview?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Stage Configuration

    @Published var isMultiStage = false

    // MARK: - Format Selection

    @Published var singleStageFormat: TournamentType = .singleElimination
    @Published var preliminaryFormat: TournamentType = .swiss
    @Published var finalsFormat: TournamentType = .singleElimination

    // MARK: - Preliminary Stage Match Settings

    @Published var generation: BeybladeGeneration = .x
    @Published var matchType: MatchType = .points4
    @Published var bestOf: BestOf = .none
    @Published var ownFinishEnabled = false

    // MARK: - Finals Stage Match Settings

    @Published var useSameSettingsForFinals = true
    @Published var finalsMatchType: MatchType = .points4
    @Published var finalsBestOf: BestOf = .none
    @Published var finalsOwnFinishEnabled = false

    // MARK: - Result

    @Published var importedTournament: Tournament?

    // MARK: - Services

    private let challongeService = ChallongeService.shared
    private let syncManager = ChallongeSyncManager.shared

    // MARK: - Computed Properties

    var hasCredentials: Bool {
        challongeService.hasStoredCredentials
    }

    var canFetchPreview: Bool {
        hasCredentials && !tournamentUrl.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    var canImport: Bool {
        hasCredentials && tournamentPreview != nil && !isLoading
    }

    /// Whether API indicates this is a multi-stage tournament (auto-detected)
    var isMultiStageDetected: Bool {
        tournamentPreview?.hasGroupStages ?? false
    }

    /// Available match types for tournaments (excludes noLimit)
    var tournamentMatchTypes: [MatchType] {
        MatchType.availableTypes(for: generation).filter { $0 != .noLimit }
    }

    // MARK: - Actions

    /// Fetches tournament preview from Challonge
    func fetchPreview() async {
        guard canFetchPreview else { return }

        isLoading = true
        error = nil
        tournamentPreview = nil

        do {
            tournamentPreview = try await syncManager.fetchPreview(from: tournamentUrl)

            // Auto-set multi-stage if detected from API
            if let preview = tournamentPreview, preview.hasGroupStages {
                isMultiStage = true
            }
        } catch let challongeError as ChallongeError {
            error = challongeError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Imports the tournament and creates local Tournament
    func confirmImport() {
        guard canImport else { return }

        isLoading = true
        error = nil

        Task {
            do {
                // Determine formats based on user selection
                let primaryFormat = isMultiStage ? preliminaryFormat : singleStageFormat
                let secondaryFormat: TournamentType? = isMultiStage ? finalsFormat : nil

                // Determine finals settings (uses same generation as preliminary)
                let finalsSettings: (MatchType, BestOf, Bool)?
                if isMultiStage && !useSameSettingsForFinals {
                    finalsSettings = (finalsMatchType, finalsBestOf, finalsOwnFinishEnabled)
                } else {
                    finalsSettings = nil
                }

                importedTournament = try await syncManager.importTournament(
                    from: tournamentUrl,
                    isMultiStage: isMultiStage,
                    primaryFormat: primaryFormat,
                    finalsFormat: secondaryFormat,
                    generation: generation,
                    matchType: matchType,
                    bestOf: bestOf,
                    ownFinishEnabled: ownFinishEnabled,
                    finalsSettings: finalsSettings
                )
            } catch let challongeError as ChallongeError {
                error = challongeError.localizedDescription
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }

    /// Resets the import flow
    func reset() {
        tournamentUrl = ""
        tournamentPreview = nil
        importedTournament = nil
        error = nil

        // Reset stage configuration
        isMultiStage = false
        singleStageFormat = .singleElimination
        preliminaryFormat = .swiss
        finalsFormat = .singleElimination

        // Reset preliminary match settings
        generation = .x
        matchType = .points4
        bestOf = .none
        ownFinishEnabled = false

        // Reset finals match settings
        useSameSettingsForFinals = true
        finalsMatchType = .points4
        finalsBestOf = .none
        finalsOwnFinishEnabled = false
    }
}
