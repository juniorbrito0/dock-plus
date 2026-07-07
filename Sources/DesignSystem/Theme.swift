import SwiftUI

// Cool Dock design system — single source of truth for palette, spacing, radius, motion.
// Distinctive identity: warm graphite glass with an electric-teal accent reserved for live/active states.

enum Theme {
    enum Color {
        static let accent = SwiftUI.Color(hex: 0x2DD4BF)      // electric teal — reserved for live/active
        static let accentSoft = SwiftUI.Color(hex: 0x2DD4BF).opacity(0.18)
        static let accentSecondary = SwiftUI.Color(hex: 0x6366F1)  // indigo — second gradient stop
        static let warning = SwiftUI.Color(hex: 0xF59E0B)
        static let danger = SwiftUI.Color(hex: 0xEF4444)
        static let positive = SwiftUI.Color(hex: 0x34D399)

        static let tileStroke = SwiftUI.Color.white.opacity(0.08)
        static let tileFill = SwiftUI.Color.white.opacity(0.16)
        static let tileFillHover = SwiftUI.Color.white.opacity(0.24)

        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
    }

    enum Radius {
        static let tile: CGFloat = 16
        static let bar: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Size {
        static let tile: CGFloat = 64          // square tile edge
        static let barHeight: CGFloat = 84     // bar height including padding
        static let iconGlyph: CGFloat = 22

        // A tile spanning `units` squares, including the inter-tile gaps it swallows.
        static func tileWidth(units: CGFloat) -> CGFloat {
            tile * units + Spacing.md * (units - 1)
        }
    }

    enum Motion {
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.78)
        static let quick = Animation.easeOut(duration: 0.16)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
