//
//  TrainingLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Training intelligence dashboard.
//

import SwiftUI

enum TrainingLayout {
    static let sectionSpacing = FormaTokens.Spacing.xxl
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
    static let scrollBottomPadding = FormaTokens.Layout.tabBarScrollPadding + FormaTokens.Spacing.md
}

struct TrainingSectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
    }
}
