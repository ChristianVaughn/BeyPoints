//
// ChallongeService.swift
// bitchat
//
// API client for Challonge v1 API with Keychain credential storage.
// Part of BeyScore Tournament System.
//

import Foundation

/// Handles all Challonge API communication
final class ChallongeService {

    // MARK: - Singleton

    static let shared = ChallongeService()

    // MARK: - Configuration

    private let baseURL = "https://api.challonge.com/v1"
    private let session: URLSession
    private let keychainManager: KeychainManagerProtocol

    // Keychain keys
    private let usernameKey = "challonge_username"
    private let apiKeyKey = "challonge_api_key"

    // Retry configuration
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0

    // MARK: - Initialization

    init(
        session: URLSession = .shared,
        keychainManager: KeychainManagerProtocol = KeychainManager()
    ) {
        self.session = session
        self.keychainManager = keychainManager
    }

    // MARK: - Credentials Management

    /// Whether credentials are stored in Keychain
    var hasStoredCredentials: Bool {
        getStoredCredentials() != nil
    }

    /// Stores credentials in Keychain
    /// - Returns: true if successful
    func storeCredentials(_ credentials: ChallongeCredentials) -> Bool {
        guard credentials.isValid else { return false }

        let usernameResult = keychainManager.saveIdentityKey(
            credentials.username.data(using: .utf8)!,
            forKey: usernameKey
        )
        let apiKeyResult = keychainManager.saveIdentityKey(
            credentials.apiKey.data(using: .utf8)!,
            forKey: apiKeyKey
        )
        return usernameResult && apiKeyResult
    }

    /// Retrieves stored credentials from Keychain
    func getStoredCredentials() -> ChallongeCredentials? {
        guard let usernameData = keychainManager.getIdentityKey(forKey: usernameKey),
              let apiKeyData = keychainManager.getIdentityKey(forKey: apiKeyKey),
              let username = String(data: usernameData, encoding: .utf8),
              let apiKey = String(data: apiKeyData, encoding: .utf8) else {
            return nil
        }
        return ChallongeCredentials(username: username, apiKey: apiKey)
    }

    /// Clears stored credentials from Keychain
    func clearCredentials() {
        _ = keychainManager.deleteIdentityKey(forKey: usernameKey)
        _ = keychainManager.deleteIdentityKey(forKey: apiKeyKey)
    }

    // MARK: - API Methods

    /// Fetches a tournament with participants and matches included
    /// - Parameter id: Tournament ID or URL slug
    /// - Returns: ChallongeTournament with nested participants and matches
    func fetchTournament(id: String) async throws -> ChallongeTournament {
        let endpoint = "/tournaments/\(id).json"
        let queryItems = [
            URLQueryItem(name: "include_participants", value: "1"),
            URLQueryItem(name: "include_matches", value: "1")
        ]

        let data = try await performRequest(endpoint: endpoint, queryItems: queryItems)

        do {
            let wrapper = try JSONDecoder().decode(ChallongeTournamentWrapper.self, from: data)
            return wrapper.tournament
        } catch {
            throw ChallongeError.decodingError(error)
        }
    }

    /// Fetches matches with optional state filter
    /// - Parameters:
    ///   - tournamentId: Tournament ID or URL slug
    ///   - state: Optional filter for match state
    /// - Returns: Array of matches
    func fetchMatches(
        tournamentId: String,
        state: ChallongeMatchState? = nil
    ) async throws -> [ChallongeMatch] {
        let endpoint = "/tournaments/\(tournamentId)/matches.json"
        var queryItems: [URLQueryItem] = []

        if let state = state {
            queryItems.append(URLQueryItem(name: "state", value: state.rawValue))
        }

        let data = try await performRequest(endpoint: endpoint, queryItems: queryItems)

        do {
            let wrappers = try JSONDecoder().decode([ChallongeMatchWrapper].self, from: data)
            return wrappers.map(\.match)
        } catch {
            throw ChallongeError.decodingError(error)
        }
    }

    /// Fetches participants for a tournament
    /// - Parameter tournamentId: Tournament ID or URL slug
    /// - Returns: Array of participants
    func fetchParticipants(tournamentId: String) async throws -> [ChallongeParticipant] {
        let endpoint = "/tournaments/\(tournamentId)/participants.json"

        let data = try await performRequest(endpoint: endpoint, queryItems: [])

        do {
            let wrappers = try JSONDecoder().decode([ChallongeParticipantWrapper].self, from: data)
            return wrappers.map(\.participant)
        } catch {
            throw ChallongeError.decodingError(error)
        }
    }

    /// Validates credentials by attempting to fetch tournaments list
    /// - Returns: true if credentials are valid
    func validateCredentials() async throws -> Bool {
        let endpoint = "/tournaments.json"
        _ = try await performRequest(endpoint: endpoint, queryItems: [])
        return true
    }

    // MARK: - URL Parsing

    /// Parses a Challonge URL or ID into the tournament identifier
    /// Handles formats like:
    /// - challonge.com/mytournament
    /// - https://challonge.com/mytournament
    /// - community.challonge.com/mytournament
    /// - mytournament (direct ID/slug)
    static func parseTournamentId(from urlOrId: String) -> String {
        let trimmed = urlOrId.trimmingCharacters(in: .whitespacesAndNewlines)

        // If it looks like a URL, extract the path
        if let url = URL(string: trimmed),
           let host = url.host,
           host.contains("challonge") {
            // Get the last path component (tournament slug)
            let slug = url.pathComponents.last ?? trimmed

            // Check for subdomain (community tournaments)
            let components = host.split(separator: ".")
            if components.count >= 3, components[0] != "www" {
                // Format: subdomain-slug
                let subdomain = String(components[0])
                return "\(subdomain)-\(slug)"
            }

            return slug
        }

        // Already an ID or slug
        return trimmed
    }

    // MARK: - Private Helpers

    private func performRequest(
        endpoint: String,
        queryItems: [URLQueryItem]
    ) async throws -> Data {
        guard let credentials = getStoredCredentials() else {
            throw ChallongeError.notAuthenticated
        }

        var components = URLComponents(string: baseURL + endpoint)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw ChallongeError.invalidTournamentUrl
        }

        var request = URLRequest(url: url)
        request.setValue(credentials.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Retry loop with exponential backoff
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ChallongeError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data

                case 401:
                    throw ChallongeError.invalidCredentials

                case 404:
                    throw ChallongeError.tournamentNotFound

                case 429:
                    // Rate limited - wait and retry
                    let delay = calculateDelay(attempt: attempt)
                    print("[Challonge] Rate limited, waiting \(delay)s before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue

                default:
                    // Try to extract error message from response
                    let message = String(data: data, encoding: .utf8)
                    throw ChallongeError.apiError(statusCode: httpResponse.statusCode, message: message)
                }

            } catch let error as ChallongeError {
                // Don't retry auth or not-found errors
                switch error {
                case .invalidCredentials, .tournamentNotFound, .notAuthenticated:
                    throw error
                default:
                    lastError = error
                }

            } catch {
                lastError = error

                // Wait before retry on network errors
                if attempt < maxRetries - 1 {
                    let delay = calculateDelay(attempt: attempt)
                    print("[Challonge] Network error, waiting \(delay)s before retry \(attempt + 1)/\(maxRetries)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries exhausted
        if let challongeError = lastError as? ChallongeError {
            throw challongeError
        } else if let lastError = lastError {
            throw ChallongeError.networkError(lastError)
        } else {
            throw ChallongeError.invalidResponse
        }
    }

    /// Calculates exponential backoff delay with jitter
    private func calculateDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...1)
        return min(exponentialDelay + jitter, maxDelay)
    }
}
