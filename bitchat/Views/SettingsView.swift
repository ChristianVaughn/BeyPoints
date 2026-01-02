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

    private var textColor: Color {
        colorScheme == .dark ? .green : Color(red: 0, green: 0.5, blue: 0)
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
}

#Preview {
    SettingsView()
}
