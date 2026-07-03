//
//  PlanHeaderSection.swift
//  Fitness Coach
//
//  Forma — Compact in-scroll Plan header.
//

import SwiftUI

struct PlanHeaderSection: View {
    let state: PlanHeaderState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.subtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#Preview {
    PlanHeaderSection(state: PlanMissionControlFixtures.loseDashboard.header)
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
