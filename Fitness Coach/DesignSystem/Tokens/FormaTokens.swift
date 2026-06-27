//
//  FormaTokens.swift
//  Fitness Coach
//
//  Forma — App-wide semantic design tokens.
//

import SwiftUI

enum FormaTokens {

    // MARK: - Color

    enum Color {
        static let canvas = SwiftUI.Color(red: 0.03, green: 0.05, blue: 0.08)
        static let surface = SwiftUI.Color.white.opacity(0.07)
        static let surfaceElevated = SwiftUI.Color.white.opacity(0.10)
        static let surfaceSubtle = SwiftUI.Color.white.opacity(0.05)
        static let border = SwiftUI.Color.white.opacity(0.12)
        static let borderStrong = SwiftUI.Color.white.opacity(0.20)
        static let accent = SwiftUI.Color.blue
        static let accentMuted = accent.opacity(0.16)
        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.68)
        static let textTertiary = SwiftUI.Color.white.opacity(0.48)
        static let textLegal = SwiftUI.Color.white.opacity(0.62)
        static let destructive = SwiftUI.Color.red
        static let warning = SwiftUI.Color.orange
        static let success = SwiftUI.Color.green
        static let googleButtonBackground = SwiftUI.Color.white
        static let googleButtonText = SwiftUI.Color(red: 0.24, green: 0.25, blue: 0.26)
        static let googleButtonBorder = border.opacity(0.35)

        /// Selected card/chip border — accent at onboarding contrast.
        static let borderSelected = accent.opacity(0.72)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
        static let pageHorizontal: CGFloat = 20
        static let sectionSpacing: CGFloat = 18
        static let cardPadding: CGFloat = 16
    }

    // MARK: - Radius

    enum Radius {
        static let card: CGFloat = 18
        static let cardLarge: CGFloat = 18
        static let button: CGFloat = 14
        static let pill: CGFloat = 999
        static let compact: CGFloat = 14
        static let iconOrb: CGFloat = 44
    }

    // MARK: - Layout

    enum Layout {
        static let minTouchTarget: CGFloat = 44
        /// Legacy clearance token; prefer `mainTabScrollBottomInset` on tab-root screens.
        static let bottomBarClearance: CGFloat = 20
        /// Extra scroll padding for sheets and pushed screens (not the main tab bar).
        static let tabBarScrollPadding: CGFloat = 32
        static let maxContentWidth: CGFloat = 520

        // MARK: Main tab bar (floating)

        /// Approximate visual height of the system floating tab bar.
        static let floatingTabBarHeight: CGFloat = 56
        /// Gap between the last scroll content and the floating tab bar.
        static let floatingTabBarBreathingRoom: CGFloat = Spacing.sm
        /// `safeAreaInset` clearance for tab-root scroll views (bar + breathing room).
        static var mainTabScrollBottomInset: CGFloat {
            floatingTabBarHeight + floatingTabBarBreathingRoom
        }
        /// Padding below the last content block inside tab-root scroll views.
        static let mainTabScrollContentPadding: CGFloat = Spacing.xs
    }

    // MARK: - Typography

    enum Typography {
        static let sectionTitle = Font.headline
        static let sectionSubtitle = Font.subheadline
        static let screenTitle = Font.largeTitle.weight(.bold)
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let caption = Font.caption
    }
}
