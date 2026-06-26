//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    static let sectionSpacing = FormaTokens.Spacing.xxl
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
}

struct JourneySectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
    }
}
