//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    /// Breathing room between major story beats.
    static let sectionSpacing = FormaMainTabLayout.sectionSpacing
    static let itemSpacing = FormaTokens.Spacing.sm
    static let compactSpacing: CGFloat = 4
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding

    /// Label-to-card gap inside a section.
    static let headerToCardSpacing = FormaMainTabLayout.sectionContentSpacing

    /// Tighter stack between momentum chip and transformation hero.
    static let heroStackSpacing = FormaTokens.Spacing.xs

    /// Extra breathing room after the flagship transformation hero.
    static let heroBottomSpacing = FormaTokens.Spacing.md

    // MARK: Progress

    static let progressBarHeight: CGFloat = 6
    static let heroProgressBarHeight: CGFloat = 8
}
