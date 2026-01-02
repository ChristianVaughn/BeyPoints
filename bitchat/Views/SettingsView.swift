//
// SettingsView.swift
// bitchat
//
// Settings page for BeyScore app configuration.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ChatViewModel
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

                        TextField("Nickname", text: $viewModel.nickname)
                            .font(.bitchatSystem(size: 16, design: .monospaced))
                            .foregroundColor(textColor)
                            .focused($isNicknameFieldFocused)
                            .autocorrectionDisabled(true)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onSubmit {
                                viewModel.validateAndSaveNickname()
                            }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.validateAndSaveNickname()
                        dismiss()
                    }
                }
            }
            .onChange(of: isNicknameFieldFocused) { isFocused in
                if !isFocused {
                    viewModel.validateAndSaveNickname()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
