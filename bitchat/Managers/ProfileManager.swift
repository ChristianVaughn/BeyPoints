//
// ProfileManager.swift
// bitchat
//
// Lightweight profile management for BeyPoints app.
// Handles nickname storage and broadcasting only.
//

import Foundation
import Combine

@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    // MARK: - Published Properties

    @Published var nickname: String = "" {
        didSet {
            let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != nickname {
                nickname = trimmed
            }
        }
    }

    // MARK: - Dependencies

    private let userDefaults = UserDefaults.standard
    private let nicknameKey = "beypoints.nickname"
    private weak var bleService: BLEService?

    // MARK: - Initialization

    private init() {
        loadNickname()
    }

    // MARK: - Configuration

    func configure(with bleService: BLEService) {
        self.bleService = bleService
        bleService.setNickname(nickname)
    }

    // MARK: - Nickname Management

    private func loadNickname() {
        if let savedNickname = userDefaults.string(forKey: nicknameKey) {
            nickname = savedNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            nickname = "anon\(Int.random(in: 1000...9999))"
            saveNickname()
        }
    }

    func saveNickname() {
        userDefaults.set(nickname, forKey: nicknameKey)
        bleService?.setNickname(nickname)
        bleService?.sendBroadcastAnnounce()
    }

    func validateAndSaveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            nickname = "anon\(Int.random(in: 1000...9999))"
        } else {
            nickname = trimmed
        }
        saveNickname()
    }
}
