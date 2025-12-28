//
// RoomStatusView.swift
// bitchat
//
// Displays current tournament room status and provides leave option.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View showing current room status with leave option.
struct RoomStatusView: View {
    @StateObject private var roomManager = TournamentRoomManager.shared
    @State private var showLeaveConfirmation = false

    var body: some View {
        if roomManager.isInRoom, let roomCode = roomManager.currentRoomCode {
            HStack(spacing: 12) {
                // Room indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("Room: \(RoomCode.formatForDisplay(roomCode.code))")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                }

                // Mode badge
                Text(roomManager.deviceMode == .master ? "Master" : "Scoreboard")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roomManager.deviceMode == .master ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)

                Spacer()

                // Leave button
                Button(action: { showLeaveConfirmation = true }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .alert("Leave Room?", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    roomManager.leaveRoom()
                }
            } message: {
                Text("Are you sure you want to leave the tournament room?")
            }
        }
    }
}

// MARK: - Compact Room Badge

/// A compact badge showing room status for use in navigation bars.
struct RoomStatusBadge: View {
    @StateObject private var roomManager = TournamentRoomManager.shared

    var body: some View {
        if roomManager.isInRoom, let roomCode = roomManager.currentRoomCode {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text(RoomCode.formatForDisplay(roomCode.code))
                    .font(.system(.caption, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(6)
        }
    }
}

// MARK: - Room Code Display

/// Large display of room code for sharing with participants.
struct RoomCodeDisplayView: View {
    let roomCode: RoomCode

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Tournament Room Code")
                .font(.headline)
                .foregroundColor(.secondary)

            // Large code display
            HStack(spacing: 4) {
                ForEach(Array(roomCode.code.enumerated()), id: \.offset) { index, digit in
                    if index == 3 {
                        Text("-")
                            .font(.system(size: 36, weight: .light, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(String(digit))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .frame(width: 40)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }

            // Copy button
            Button(action: copyCode) {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied!" : "Copy Code")
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }

            Text("Share this code with scoreboard devices to let them join")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func copyCode() {
        UIPasteboard.general.string = roomCode.code
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Not In Room View

/// View shown when not in a room, with option to join.
struct NotInRoomView: View {
    @State private var showJoinSheet = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Not in a Tournament Room")
                .font(.headline)

            Text("Join a room to participate in a tournament")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Join Room") {
                showJoinSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showJoinSheet) {
            RoomCodeEntryView()
        }
    }
}

// MARK: - Previews

#Preview("Room Status") {
    VStack {
        RoomStatusView()
        Spacer()
    }
    .padding()
}

#Preview("Room Code Display") {
    RoomCodeDisplayView(roomCode: RoomCode(code: "847291")!)
        .padding()
}

#Preview("Not In Room") {
    NotInRoomView()
}
