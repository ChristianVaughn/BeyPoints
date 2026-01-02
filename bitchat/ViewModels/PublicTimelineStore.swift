//
// PublicTimelineStore.swift
// bitchat
//
// Maintains mesh public timeline with simple caps and helpers.
//

import Foundation

struct PublicTimelineStore {
    private var meshTimeline: [BitchatMessage] = []

    private let meshCap: Int

    init(meshCap: Int, geohashCap: Int = 0) {
        self.meshCap = meshCap
    }

    mutating func append(_ message: BitchatMessage, to channel: ChannelID) {
        switch channel {
        case .mesh:
            guard !meshTimeline.contains(where: { $0.id == message.id }) else { return }
            meshTimeline.append(message)
            trimMeshTimelineIfNeeded()
        }
    }

    mutating func messages(for channel: ChannelID) -> [BitchatMessage] {
        switch channel {
        case .mesh:
            return meshTimeline
        }
    }

    mutating func clear(channel: ChannelID) {
        switch channel {
        case .mesh:
            meshTimeline.removeAll()
        }
    }

    @discardableResult
    mutating func removeMessage(withID id: String) -> BitchatMessage? {
        if let index = meshTimeline.firstIndex(where: { $0.id == id }) {
            return meshTimeline.remove(at: index)
        }
        return nil
    }

    // Keep for API compatibility but no-ops for geohash
    mutating func queueGeohashSystemMessage(_ content: String) {}
    mutating func drainPendingGeohashSystemMessages() -> [String] { [] }
    func geohashKeys() -> [String] { [] }

    private mutating func trimMeshTimelineIfNeeded() {
        guard meshTimeline.count > meshCap else { return }
        meshTimeline = Array(meshTimeline.suffix(meshCap))
    }
}
