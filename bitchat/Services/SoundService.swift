//
// SoundService.swift
// bitchat
//
// Manages sound effects for the scoring system.
// Part of BeyScore Tournament System.
//

import Foundation
import AVFoundation
import AudioToolbox
import UIKit

/// Service for playing sound effects.
final class SoundService {

    static let shared = SoundService()

    // MARK: - Configuration

    private var isSoundEnabled = true
    private var volume: Float = 1.0

    // MARK: - Audio Players

    private var scorePlayer: AVAudioPlayer?
    private var gameEndPlayer: AVAudioPlayer?
    private var matchEndPlayer: AVAudioPlayer?
    private var assignedPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?

    // MARK: - Initialization

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func preloadSounds() {
        scorePlayer = loadSound(named: "score")
        gameEndPlayer = loadSound(named: "game_end")
        matchEndPlayer = loadSound(named: "match_end")
        assignedPlayer = loadSound(named: "assigned")
        warningPlayer = loadSound(named: "warning")
        errorPlayer = loadSound(named: "error")
    }

    private func loadSound(named name: String) -> AVAudioPlayer? {
        // Try to load from bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            } catch {
                print("Failed to load sound \(name): \(error)")
            }
        }

        // If no custom sound, use system sound as fallback
        return nil
    }

    // MARK: - Settings

    /// Enables or disables sound effects.
    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }

    /// Sets the volume level (0.0 to 1.0).
    func setVolume(_ level: Float) {
        volume = max(0, min(1, level))
        UserDefaults.standard.set(volume, forKey: "soundVolume")

        scorePlayer?.volume = volume
        gameEndPlayer?.volume = volume
        matchEndPlayer?.volume = volume
        assignedPlayer?.volume = volume
        warningPlayer?.volume = volume
        errorPlayer?.volume = volume
    }

    /// Loads saved settings.
    func loadSettings() {
        isSoundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            isSoundEnabled = true  // Default to enabled
        }

        volume = UserDefaults.standard.float(forKey: "soundVolume")
        if volume == 0 && UserDefaults.standard.object(forKey: "soundVolume") == nil {
            volume = 1.0  // Default volume
        }

        setVolume(volume)
    }

    // MARK: - Sound Effects

    /// Plays the score sound effect.
    func playScoreSound() {
        guard isSoundEnabled else { return }

        if let player = scorePlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1104)  // Tock sound
        }
    }

    /// Plays the game end sound effect.
    func playGameEndSound() {
        guard isSoundEnabled else { return }

        if let player = gameEndPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1025)  // New mail sound
        }
    }

    /// Plays the match end (winner) sound effect.
    func playMatchEndSound() {
        guard isSoundEnabled else { return }

        if let player = matchEndPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sounds - play a sequence
            AudioServicesPlaySystemSound(1025)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AudioServicesPlaySystemSound(1025)
            }
        }
    }

    /// Plays the match assigned notification sound.
    func playAssignedSound() {
        guard isSoundEnabled else { return }

        if let player = assignedPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1003)  // Received message
        }
    }

    /// Plays the warning sound effect.
    func playWarningSound() {
        guard isSoundEnabled else { return }

        if let player = warningPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1073)  // VC call ended
        }
    }

    /// Plays the error sound effect.
    func playErrorSound() {
        guard isSoundEnabled else { return }

        if let player = errorPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            AudioServicesPlaySystemSound(1073)
        }
    }

    // MARK: - Haptic Feedback

    /// Provides haptic feedback for score events.
    func playScoreHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Provides haptic feedback for game/match end.
    func playSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Provides haptic feedback for warnings/errors.
    func playWarningHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Provides haptic feedback for errors.
    func playErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Combined Effects

    /// Plays score sound with haptic feedback.
    func onScoreApplied() {
        playScoreSound()
        playScoreHaptic()
    }

    /// Plays game end sound with haptic feedback.
    func onGameEnd() {
        playGameEndSound()
        playSuccessHaptic()
    }

    /// Plays match end sound with haptic feedback.
    func onMatchEnd() {
        playMatchEndSound()
        playSuccessHaptic()
    }

    /// Plays assigned sound with haptic feedback.
    func onMatchAssigned() {
        playAssignedSound()
        playScoreHaptic()
    }

    /// Plays warning sound with haptic feedback.
    func onWarning() {
        playWarningSound()
        playWarningHaptic()
    }

    /// Plays penalty sound with haptic feedback.
    func onPenalty() {
        playErrorSound()
        playErrorHaptic()
    }
}
