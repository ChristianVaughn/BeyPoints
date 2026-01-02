//
// ChannelID.swift
// bitchat
//
// Minimal channel identifier for mesh-only operation.
//

import Foundation

/// Channel identifier - simplified for mesh-only operation.
enum ChannelID: Equatable, Hashable {
    case mesh

    var isMesh: Bool { true }

    var key: String { "mesh" }
}
