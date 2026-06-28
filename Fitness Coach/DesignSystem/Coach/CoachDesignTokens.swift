//
//  CoachDesignTokens.swift
//  Fitness Coach
//
//  FitPilot AI — Design tokens for the Coach command center.
//

import SwiftUI

enum CoachDesignTokens {

    // MARK: Color

    /// Semantic colors resolved from the active Forma theme on each access.
    enum Color {
        @MainActor
        private static var active: FormaThemeColors { FormaThemeAccess.currentColors }

        @MainActor
        static var background: SwiftUI.Color { active.canvas }
        @MainActor
        static var elevatedSurface: SwiftUI.Color { active.surfaceElevated }
        @MainActor
        static var chipFill: SwiftUI.Color { active.surface }
        @MainActor
        static var chipStroke: SwiftUI.Color { active.border }
        @MainActor
        static var composerFill: SwiftUI.Color { active.surfaceElevated }
        @MainActor
        static var composerStroke: SwiftUI.Color { active.border }
        @MainActor
        static var primaryText: SwiftUI.Color { active.textPrimary }
        @MainActor
        static var secondaryText: SwiftUI.Color { active.textSecondary }
        @MainActor
        static var tertiaryText: SwiftUI.Color { active.textTertiary }
        @MainActor
        static var accent: SwiftUI.Color { active.accent }
        @MainActor
        static var ctaBackground: SwiftUI.Color { active.ctaBackground }
        @MainActor
        static var border: SwiftUI.Color { active.border }
        @MainActor
        static var userBubble: SwiftUI.Color { active.surfaceElevated }
        @MainActor
        static var confirmationLabel: SwiftUI.Color { active.textTertiary }
        @MainActor
        static var confirmationValue: SwiftUI.Color { active.textLegal }
        @MainActor
        static var textLegal: SwiftUI.Color { active.textLegal }
        @MainActor
        static var warning: SwiftUI.Color { active.warning }
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs = FormaTokens.Spacing.xs
        static let sm = FormaTokens.Spacing.sm
        static let md = FormaTokens.Spacing.md
        static let lg = FormaTokens.Spacing.lg
        static let xl = FormaTokens.Spacing.xl
        /// Extra vertical breathing room in empty Coach state.
        static let xxl: CGFloat = 40
    }

    // MARK: Radius

    enum Radius {
        static let chip = FormaTokens.Radius.pill
        /// Rounded composer bar — taller than standard Forma buttons.
        static let composer: CGFloat = 24
        static let bubble = FormaTokens.Radius.card
        static let attachment = FormaTokens.Radius.compact
    }

    // MARK: Typography

    enum Typography {
        static let largeTitle = FormaTokens.Typography.screenTitle
        static let subtitle = Font.system(size: 15, weight: .regular, design: .default)
        static let chip = Font.system(size: 15, weight: .medium, design: .default)
        static let hint = Font.system(size: 15, weight: .regular, design: .default)
        static let hintLabel = Font.system(size: 13, weight: .medium, design: .default)
        static let messageBody = Font.system(size: 16, weight: .regular, design: .default)
        static let messageUser = Font.system(size: 16, weight: .medium, design: .default)
        static let confirmationTitle = Font.system(size: 15, weight: .semibold, design: .default)
        static let confirmationMetric = Font.system(size: 14, weight: .regular, design: .default)
        static let confirmationValue = Font.system(size: 14, weight: .medium, design: .default)
        static let composer = Font.system(size: 16, weight: .regular, design: .default)
    }

    // MARK: Layout

    enum Layout {
        static let chipHeight: CGFloat = 36
        static let chipMinTouch = FormaTokens.Layout.minTouchTarget
        static let composerBarHeight: CGFloat = 48
        static let composerMinHeight: CGFloat = 48
        static let composerMaxHeight: CGFloat = 120
        static let composerMaxLines = 5
        static let composerTrailingWidth: CGFloat = 40
        static let composerButtonSize: CGFloat = 32
        static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
        static let messageSpacing = Spacing.lg
        static let maxBubbleWidthRatio: CGFloat = 0.82
        /// Lifts the composer above the floating main tab bar.
        static let bottomChromeInset = FormaTokens.Layout.mainTabScrollBottomInset
    }

    // MARK: Animation

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.28)
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    }
}
