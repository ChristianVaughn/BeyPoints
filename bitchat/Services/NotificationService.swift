//
// NotificationService.swift
// bitchat
//
// Manages local notifications for tournament events.
// Only sends notifications when the app is not actively in use.
// Part of BeyScore Tournament System.
//

import Foundation
import UserNotifications

/// Service for scheduling local notifications when app is backgrounded.
@MainActor
final class NotificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Published Properties

    /// Whether the app is currently active in the foreground
    @Published private(set) var isAppActive: Bool = true

    // MARK: - Initialization

    private init() {}

    // MARK: - App Lifecycle

    /// Call when app becomes active (foreground)
    func appDidBecomeActive() {
        isAppActive = true
    }

    /// Call when app enters background or becomes inactive
    func appDidEnterBackground() {
        isAppActive = false
    }

    // MARK: - Permission Request

    /// Request notification permissions from the user
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationService] Permission request error: \(error.localizedDescription)")
            } else {
                print("[NotificationService] Permission granted: \(granted)")
            }
        }
    }

    // MARK: - Tournament Notifications

    /// Notify scoreboard that a match has been assigned to them
    /// - Parameters:
    ///   - player1: First player name
    ///   - player2: Second player name
    func notifyMatchAssigned(player1: String, player2: String) {
        guard !isAppActive else { return }

        scheduleNotification(
            title: "Match Assigned",
            body: "\(player1) vs \(player2)",
            identifier: "match-assigned-\(UUID().uuidString)"
        )
    }

    /// Notify master that a score has been submitted and needs approval
    /// - Parameters:
    ///   - matchName: Display name of the match
    ///   - winner: Name of the winning player
    func notifyScoreSubmitted(matchName: String, winner: String) {
        guard !isAppActive else { return }

        scheduleNotification(
            title: "Score Submitted",
            body: "\(matchName): \(winner) wins - Tap to approve",
            identifier: "score-submitted-\(UUID().uuidString)"
        )
    }

    // MARK: - Private Helpers

    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Deliver immediately (nil trigger)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}
