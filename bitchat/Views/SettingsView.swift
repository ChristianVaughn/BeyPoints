//
// SettingsView.swift
// bitchat
//
// Settings page for BeyScore app configuration.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isNicknameFieldFocused: Bool

    // Challonge credentials
    @State private var challongeUsername = ""
    @State private var challongeApiKey = ""
    @State private var isValidatingCredentials = false
    @State private var credentialError: String?
    @State private var credentialSuccess = false

    private let challongeService = ChallongeService.shared
    private let syncManager = ChallongeSyncManager.shared

    private var textColor: Color {
        colorScheme == .dark ? .green : Color(red: 0, green: 0.5, blue: 0)
    }

    private var hasCredentials: Bool {
        challongeService.hasStoredCredentials
    }

    private var canSaveCredentials: Bool {
        !challongeUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
        !challongeApiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile")) {
                    HStack {
                        Text("@")
                            .font(.bitchatSystem(size: 16, design: .monospaced))
                            .foregroundColor(.secondary)

                        TextField("Nickname", text: $profileManager.nickname)
                            .font(.bitchatSystem(size: 16, design: .monospaced))
                            .foregroundColor(textColor)
                            .focused($isNicknameFieldFocused)
                            .autocorrectionDisabled(true)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onSubmit {
                                profileManager.validateAndSaveNickname()
                            }
                    }
                }

                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Challonge Credentials Section
                challongeCredentialsSection

                // API Usage Section (only show if credentials exist)
                if hasCredentials {
                    challongeApiUsageSection
                    challongeManageSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        profileManager.validateAndSaveNickname()
                        dismiss()
                    }
                }
            }
            .onChange(of: isNicknameFieldFocused) { isFocused in
                if !isFocused {
                    profileManager.validateAndSaveNickname()
                }
            }
        }
    }

    // MARK: - Challonge Credentials Section

    private var challongeCredentialsSection: some View {
        Section {
            if hasCredentials {
                Label("Credentials saved", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                TextField("Challonge Username", text: $challongeUsername)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                SecureField("API Key", text: $challongeApiKey)

                Button {
                    Task { await saveCredentials() }
                } label: {
                    if isValidatingCredentials {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Validating...")
                        }
                    } else {
                        Text("Save Credentials")
                    }
                }
                .disabled(!canSaveCredentials || isValidatingCredentials)

                if let error = credentialError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if credentialSuccess {
                    Label("Credentials validated successfully", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        } header: {
            Text("Challonge")
        } footer: {
            if !hasCredentials {
                Text("Find your API key at challonge.com/settings/developer")
            }
        }
    }

    // MARK: - API Usage Section

    private var challongeApiUsageSection: some View {
        Section {
            HStack {
                Text("API Calls Remaining")
                Spacer()
                Text("\(syncManager.remainingApiCalls) / 500")
                    .foregroundColor(syncManager.isApproachingLimit ? .orange : .secondary)
            }

            if syncManager.isApproachingLimit {
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

    private var challongeManageSection: some View {
        Section {
            Button("Clear Saved Credentials", role: .destructive) {
                challongeService.clearCredentials()
                challongeUsername = ""
                challongeApiKey = ""
                credentialError = nil
                credentialSuccess = false
            }
        }
    }

    // MARK: - Actions

    private func saveCredentials() async {
        isValidatingCredentials = true
        credentialError = nil
        credentialSuccess = false

        let credentials = ChallongeCredentials(
            username: challongeUsername.trimmingCharacters(in: .whitespaces),
            apiKey: challongeApiKey.trimmingCharacters(in: .whitespaces)
        )

        guard challongeService.storeCredentials(credentials) else {
            credentialError = "Failed to save credentials"
            isValidatingCredentials = false
            return
        }

        // Validate credentials
        do {
            _ = try await challongeService.validateCredentials()
            // Clear input fields after successful save
            challongeUsername = ""
            challongeApiKey = ""
            credentialSuccess = true
        } catch {
            // Clear stored credentials if validation failed
            challongeService.clearCredentials()
            credentialError = "Invalid credentials: \(error.localizedDescription)"
        }

        isValidatingCredentials = false
    }
}

#Preview {
    SettingsView()
}
