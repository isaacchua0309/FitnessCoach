//
//  CoachDesignTokens.swift
//  Fitness Coach
//
//  FitPilot AI — Design tokens for the Coach command center.
//

import SwiftUI

enum CoachDesignTokens {

    // MARK: Color

    enum Color {
        static let background = SwiftUI.Color.black
        static let elevatedSurface = SwiftUI.Color(white: 0.11)
        static let chipFill = SwiftUI.Color.white.opacity(0.08)
        static let chipStroke = SwiftUI.Color.white.opacity(0.12)
        static let composerFill = SwiftUI.Color(white: 0.14)
        static let composerStroke = SwiftUI.Color.white.opacity(0.10)
        static let primaryText = SwiftUI.Color.white
        static let secondaryText = SwiftUI.Color.white.opacity(0.55)
        static let tertiaryText = SwiftUI.Color.white.opacity(0.35)
        static let accent = SwiftUI.Color(red: 0.35, green: 0.78, blue: 0.98)
        static let userBubble = SwiftUI.Color(white: 0.18)
        static let confirmationLabel = SwiftUI.Color.white.opacity(0.45)
        static let confirmationValue = SwiftUI.Color.white.opacity(0.92)
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40
    }

    // MARK: Radius

    enum Radius {
        static let chip: CGFloat = 999
        static let composer: CGFloat = 24
        static let bubble: CGFloat = 18
        static let attachment: CGFloat = 14
    }

    // MARK: Typography

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
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
        static let chipMinTouch: CGFloat = 44
        static let composerBarHeight: CGFloat = 48
        static let composerMinHeight: CGFloat = 48
        static let composerMaxHeight: CGFloat = 120
        static let composerMaxLines = 5
        static let composerTrailingWidth: CGFloat = 40
        static let composerButtonSize: CGFloat = 32
        static let horizontalPadding: CGFloat = Spacing.lg
        static let messageSpacing: CGFloat = Spacing.lg
        static let maxBubbleWidthRatio: CGFloat = 0.82
    }

    // MARK: Animation

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.18)
        static let standard = Animation.easeInOut(duration: 0.28)
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    }
}
