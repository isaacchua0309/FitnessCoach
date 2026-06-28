//
//  FormaTokens.swift
//  Fitness Coach
//
//  Forma — App-wide semantic design tokens.
//

import SwiftUI

enum FormaTokens {

    // MARK: - Color

    /// Semantic color facade over the active resolved theme.
    ///
    /// Values resolve through `FormaThemeAccess.currentColors`, which tracks the root theme.
    /// In SwiftUI views, prefer `@Environment(\.formaColors)` when possible.
    enum Color {
        @MainActor
        private static var active: FormaThemeColors { FormaThemeAccess.currentColors }

        @MainActor
        static var canvas: SwiftUI.Color { active.canvas }
        @MainActor
        static var surface: SwiftUI.Color { active.surface }
        @MainActor
        static var surfaceElevated: SwiftUI.Color { active.surfaceElevated }
        @MainActor
        static var surfaceSubtle: SwiftUI.Color { active.surfaceSubtle }
        @MainActor
        static var border: SwiftUI.Color { active.border }
        @MainActor
        static var borderStrong: SwiftUI.Color { active.borderStrong }
        @MainActor
        static var accent: SwiftUI.Color { active.accent }
        @MainActor
        static var accentMuted: SwiftUI.Color { active.accentMuted }
        @MainActor
        static var textPrimary: SwiftUI.Color { active.textPrimary }
        @MainActor
        static var textSecondary: SwiftUI.Color { active.textSecondary }
        @MainActor
        static var textTertiary: SwiftUI.Color { active.textTertiary }
        @MainActor
        static var textLegal: SwiftUI.Color { active.textLegal }
        @MainActor
        static var ctaBackground: SwiftUI.Color { active.ctaBackground }
        @MainActor
        static var ctaText: SwiftUI.Color { active.ctaText }
        @MainActor
        static var progress: SwiftUI.Color { active.progress }
        @MainActor
        static var progressTrack: SwiftUI.Color { active.progressTrack }
        @MainActor
        static var chartPrimary: SwiftUI.Color { active.chartPrimary }
        @MainActor
        static var chartSecondary: SwiftUI.Color { active.chartSecondary }
        @MainActor
        static var shadow: SwiftUI.Color { active.shadow }
        @MainActor
        static var destructive: SwiftUI.Color { active.destructive }
        @MainActor
        static var warning: SwiftUI.Color { active.warning }
        @MainActor
        static var success: SwiftUI.Color { active.success }
        @MainActor
        static var googleButtonBackground: SwiftUI.Color { active.googleButtonBackground }
        @MainActor
        static var googleButtonForeground: SwiftUI.Color { active.googleButtonForeground }
        @MainActor
        static var googleButtonText: SwiftUI.Color { active.googleButtonText }
        @MainActor
        static var googleButtonBorder: SwiftUI.Color { active.googleButtonBorder }
        @MainActor
        static var googleButtonShadow: SwiftUI.Color { active.googleButtonShadow }
        @MainActor
        static var googleButtonShadowLoading: SwiftUI.Color { active.googleButtonShadowLoading }

        /// Selected card/chip border — accent at onboarding contrast.
        @MainActor
        static var borderSelected: SwiftUI.Color { active.borderSelected }
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
        static let caption2 = Font.caption2
    }
}
