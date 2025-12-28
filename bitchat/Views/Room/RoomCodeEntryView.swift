//
// RoomCodeEntryView.swift
// bitchat
//
// UI for entering a 6-digit tournament room code.
// Part of BeyScore Tournament System.
//

import SwiftUI

/// View for entering a tournament room code.
struct RoomCodeEntryView: View {
    @StateObject private var roomManager = TournamentRoomManager.shared

    @State private var codeInput: String = ""
    @State private var isJoining: Bool = false
    @State private var isWaitingForConfirmation: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var confirmationTimeout: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    /// Callback when successfully joined a room
    var onJoined: ((RoomCode) -> Void)?

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Join Tournament Room")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter the 6-digit room code from the tournament master")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Code Input
                VStack(spacing: 16) {
                    CodeInputField(code: $codeInput)

                    if !RoomCode.isValid(codeInput) && !codeInput.isEmpty {
                        Text("Enter exactly 6 digits")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Join Button
                Button(action: joinRoom) {
                    HStack {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            if isWaitingForConfirmation {
                                Text("Connecting...")
                                    .padding(.leading, 8)
                            }
                        } else {
                            Text("Join Room")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoomCode.isValid(codeInput) ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!RoomCode.isValid(codeInput) || isJoining)
                .padding(.horizontal)

                Spacer()

                // Create Room Option (for masters)
                VStack(spacing: 8) {
                    Text("Are you the tournament organizer?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Create New Room") {
                        createRoom()
                    }
                    .font(.subheadline)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private func joinRoom() {
        isJoining = true
        errorMessage = nil

        do {
            // 1. Validate and set up local state
            try roomManager.joinRoom(codeString: codeInput)
            print("[BeyScore] Scoreboard joined room locally: \(codeInput)")

            // 2. Set up confirmation handler BEFORE sending message
            isWaitingForConfirmation = true
            TournamentMessageHandler.shared.onRoomJoined = { [self] success, info in
                Task { @MainActor in
                    self.handleJoinConfirmation(success: success, info: info)
                }
            }

            // 3. Start timeout (5 seconds)
            confirmationTimeout = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    if isWaitingForConfirmation {
                        handleJoinTimeout()
                    }
                }
            }

            // 4. Send join request to Master
            print("[BeyScore] Scoreboard sending JoinRoomMessage...")
            TournamentMessageHandler.shared.sendJoinRoom()

        } catch let error as TournamentRoomError {
            errorMessage = error.localizedDescription
            showError = true
            isJoining = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isJoining = false
        }
    }

    private func handleJoinConfirmation(success: Bool, info: String?) {
        confirmationTimeout?.cancel()
        confirmationTimeout = nil
        isWaitingForConfirmation = false
        isJoining = false

        if success {
            print("[BeyScore] Room join confirmed by Master: \(info ?? "no info")")
            if let roomCode = roomManager.currentRoomCode {
                onJoined?(roomCode)
            }
            dismiss()
        } else {
            // Master rejected - leave room and show error
            print("[BeyScore] Room join rejected by Master: \(info ?? "no reason")")
            roomManager.leaveRoom()
            errorMessage = info ?? "Failed to join room"
            showError = true
        }
    }

    private func handleJoinTimeout() {
        confirmationTimeout = nil
        isWaitingForConfirmation = false
        isJoining = false
        roomManager.leaveRoom()
        errorMessage = "No response from tournament master. Check the room code and make sure the master device is nearby."
        showError = true
        print("[BeyScore] Room join timed out - no response from Master")
    }

    private func createRoom() {
        do {
            let roomCode = try roomManager.createRoom()
            onJoined?(roomCode)
            dismiss()
        } catch let error as TournamentRoomError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Code Input Field

/// Custom input field for the 6-digit code with individual digit boxes.
struct CodeInputField: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden text field for input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0)
                .onChange(of: code) { newValue in
                    // Filter to only digits and limit to 6
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count <= 6 {
                        code = filtered
                    } else {
                        code = String(filtered.prefix(6))
                    }
                }

            // Visual digit boxes
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    DigitBox(
                        digit: digitAt(index),
                        isActive: index == code.count && isFocused
                    )
                }
            }
            .onTapGesture {
                isFocused = true
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private func digitAt(_ index: Int) -> String {
        guard index < code.count else { return "" }
        let idx = code.index(code.startIndex, offsetBy: index)
        return String(code[idx])
    }
}

/// Individual digit box for the code input.
struct DigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue : Color.gray.opacity(0.5), lineWidth: isActive ? 2 : 1)
                .frame(width: 44, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                )

            Text(digit)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Preview

#Preview {
    RoomCodeEntryView()
}
