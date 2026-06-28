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

    /// Logged days required before showing the full monthly calendar grid.
    static let minimumLoggedDaysForCalendar = 3

    /// Padding below the last Journey section (see `FormaMainTabLayout`).
    static let scrollBottomContentPadding = FormaMainTabLayout.scrollContentBottomPadding
}

