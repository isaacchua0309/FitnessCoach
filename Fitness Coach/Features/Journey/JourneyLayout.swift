//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    static let sectionSpacing = FormaTokens.Spacing.lg
    static let itemSpacing = FormaFeatureLayout.itemSpacing
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding

    /// Extra breathing room after the flagship transformation hero.
    static let heroBottomSpacing = FormaTokens.Spacing.md

    /// Padding below the last Journey section (see `FormaMainTabLayout`).
    static let scrollBottomContentPadding = FormaFeatureLayout.scrollBottomPadding
}

