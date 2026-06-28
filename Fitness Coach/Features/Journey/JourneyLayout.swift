//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    static let sectionSpacing = FormaTokens.Spacing.lg
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal

    /// Extra breathing room after the flagship transformation hero.
    static let heroBottomSpacing = FormaTokens.Spacing.md

    /// Padding below the last Journey section (see `FormaMainTabLayout`).
    static let scrollBottomContentPadding = FormaMainTabLayout.scrollContentBottomPadding
}

