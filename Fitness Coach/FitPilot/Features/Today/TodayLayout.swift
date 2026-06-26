//
//  TodayLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Today screen.
//

import SwiftUI

enum TodayLayout {
    static let sectionSpacing = FormaTokens.Spacing.xxl
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
}

struct TodaySectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
    }
}
