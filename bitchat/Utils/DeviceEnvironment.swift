//
// DeviceEnvironment.swift
// bitchat
//
// Device detection and responsive sizing utilities for iPad support.
// Part of BeyPoints Tournament System.
//

import SwiftUI

/// Provides device-specific sizing and layout information
enum DeviceEnvironment {

    /// Check if running on iPad
    static var isIPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    /// Check if running on iPad Mini (smaller screen)
    static var isIPadMini: Bool {
        guard isIPad else { return false }
        #if os(iOS)
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let minDimension = min(screenWidth, screenHeight)
        return minDimension < 750 // iPad Mini has ~744pt short edge
        #else
        return false
        #endif
    }

    // MARK: - Bracket Sizing

    /// Minimum bracket column width based on device
    static var minBracketColumnWidth: CGFloat {
        isIPad ? (isIPadMini ? 200 : 220) : 180
    }

    /// Maximum bracket column width
    static var maxBracketColumnWidth: CGFloat {
        isIPad ? 320 : 200
    }

    // MARK: - Grid Sizing

    /// RoundRobin grid cell size based on device
    static var roundRobinCellSize: CGFloat {
        isIPad ? (isIPadMini ? 50 : 60) : 40
    }

    /// RoundRobin header width
    static var roundRobinHeaderWidth: CGFloat {
        isIPad ? 100 : 80
    }

    /// Standings table column widths
    static var standingsRankWidth: CGFloat {
        isIPad ? 40 : 30
    }

    static var standingsStatWidth: CGFloat {
        isIPad ? 40 : 30
    }

    static var standingsPointsWidth: CGFloat {
        isIPad ? 55 : 45
    }

    // MARK: - Card Sizing

    /// Match selection card width
    static var matchCardWidth: CGFloat {
        isIPad ? 200 : 160
    }

    /// Device selection card width
    static var deviceCardWidth: CGFloat {
        isIPad ? 150 : 120
    }

    // MARK: - Scoreboard Sizing

    /// Score font size
    static var scoreFontSize: CGFloat {
        isIPad ? 120 : 96
    }

    /// Compact score font size (landscape)
    static var compactScoreFontSize: CGFloat {
        isIPad ? 96 : 72
    }

    /// Card content padding
    static var cardPadding: CGFloat {
        isIPad ? 28 : 20
    }

    /// Chip spacing
    static var chipSpacing: CGFloat {
        isIPad ? 16 : 12
    }

    // MARK: - Split View

    /// Sidebar width for NavigationSplitView
    static var sidebarWidth: CGFloat {
        isIPad ? (isIPadMini ? 280 : 320) : 300
    }
}

// MARK: - Responsive Layout Enum

/// Represents the current layout context based on available space
enum ResponsiveLayout {
    case compact      // iPhone or narrow multitasking
    case regular      // iPad in reasonable space
    case expanded     // iPad Pro landscape or full screen

    /// Determine layout from size class and container width
    static func from(
        horizontalSizeClass: UserInterfaceSizeClass?,
        containerWidth: CGFloat
    ) -> ResponsiveLayout {
        guard DeviceEnvironment.isIPad else { return .compact }

        // Compact size class means Slide Over or narrow Split View
        if horizontalSizeClass == .compact {
            return .compact
        }

        // Determine based on actual width
        if containerWidth > 1100 {
            return .expanded
        } else if containerWidth > 700 {
            return .regular
        } else {
            return .compact
        }
    }
}
