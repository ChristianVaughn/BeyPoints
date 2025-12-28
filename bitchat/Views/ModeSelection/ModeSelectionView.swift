//
// ModeSelectionView.swift
// bitchat
//
// Initial screen for selecting Tournament Master or Scoreboard mode.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// Initial mode selection screen shown on first launch.
struct ModeSelectionView: View {
    @StateObject private var appState = AppState.shared

    @State private var selectedMode: AppMode?
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding(.top, 40)

                Text("BeyScore")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Tournament System")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)

            // Mode Selection Cards
            VStack(spacing: 16) {
                Text("Select Your Role")
                    .font(.headline)
                    .foregroundColor(.secondary)

                ForEach(AppMode.allCases, id: \.self) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        action: { selectMode(mode) }
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            // Continue Button
            if selectedMode != nil {
                Button(action: confirmSelection) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
        .alert("Confirm Selection", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                if let mode = selectedMode {
                    appState.setMode(mode)
                }
            }
        } message: {
            if let mode = selectedMode {
                Text("You selected \(mode.displayName). You can change this later in settings.")
            }
        }
    }

    private func selectMode(_ mode: AppMode) {
        withAnimation {
            if selectedMode == mode {
                selectedMode = nil
            } else {
                selectedMode = mode
            }
        }
    }

    private func confirmSelection() {
        showConfirmation = true
    }
}

// MARK: - Mode Card

/// Card displaying a selectable mode option.
struct ModeCard: View {
    let mode: AppMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: mode.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : modeColor)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(isSelected ? modeColor : modeColor.opacity(0.15))
                    )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? modeColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : modeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var modeColor: Color {
        switch mode {
        case .master:
            return .orange
        case .scoreboard:
            return .blue
        }
    }
}

// MARK: - Mode Switch Button (for settings)

/// Button for switching modes in settings.
struct ModeSwitchButton: View {
    @StateObject private var appState = AppState.shared
    @State private var showModeSelection = false

    var body: some View {
        Button(action: { showModeSelection = true }) {
            HStack {
                if let mode = appState.currentMode {
                    Image(systemName: mode.iconName)
                        .foregroundColor(mode == .master ? .orange : .blue)

                    VStack(alignment: .leading) {
                        Text("Current Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Text("Change")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showModeSelection) {
            ModeSelectionSheet()
        }
    }
}

// MARK: - Mode Selection Sheet

/// Sheet version of mode selection for changing modes.
struct ModeSelectionSheet: View {
    @StateObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: AppMode?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Change your role in the tournament system")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)

                ForEach(AppMode.allCases, id: \.self) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode || (selectedMode == nil && appState.currentMode == mode),
                        action: { selectedMode = mode }
                    )
                }

                Spacer()

                if let mode = selectedMode, mode != appState.currentMode {
                    Button(action: {
                        appState.setMode(mode)
                        dismiss()
                    }) {
                        Text("Switch to \(mode.displayName)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("Change Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Mode Selection") {
    ModeSelectionView()
}

#Preview("Mode Card - Master") {
    ModeCard(mode: .master, isSelected: false, action: {})
        .padding()
}

#Preview("Mode Card - Scoreboard Selected") {
    ModeCard(mode: .scoreboard, isSelected: true, action: {})
        .padding()
}
