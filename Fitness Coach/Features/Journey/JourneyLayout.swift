//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    /// Breathing room between major story beats.
    static let sectionSpacing = FormaTokens.Spacing.xl
    static let itemSpacing = FormaTokens.Spacing.sm
    static let compactSpacing: CGFloat = 4
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding

    /// Label-to-card gap inside a section.
    static let headerToCardSpacing = FormaTokens.Spacing.xs

    /// Tighter stack between momentum chip and transformation hero.
    static let heroStackSpacing = FormaTokens.Spacing.xs

    /// Extra breathing room after the flagship transformation hero.
    static let heroBottomSpacing = FormaTokens.Spacing.md

    // MARK: Card padding

    static let cardPaddingHorizontal = FormaTokens.Spacing.md
    static let heroCardPaddingVertical = FormaTokens.Spacing.md + 2
    static let featuredCardPaddingVertical = FormaTokens.Spacing.md
    static let standardCardPaddingVertical = FormaTokens.Spacing.sm + 2
    static let quietCardPaddingVertical = FormaTokens.Spacing.sm

    // MARK: Progress

    static let progressBarHeight: CGFloat = 6
    static let heroProgressBarHeight: CGFloat = 8

    /// Padding below the last Journey section (pairs with `formaMainTabScrollInsets`).
    static let scrollBottomContentPadding = FormaTokens.Spacing.lg
}
