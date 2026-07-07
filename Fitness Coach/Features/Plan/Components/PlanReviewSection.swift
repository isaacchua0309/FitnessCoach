//
//  PlanReviewSection.swift
//  Fitness Coach
//
//  Forma — Next Review cadence card.
//

import SwiftUI

struct PlanReviewSection: View {
    let state: PlanReviewState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.headerToCardSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(state.headline)
                        .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    Text("\"\(state.bodyCopy)\"")
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if let weighInHint = state.weighInHint {
                        Text(weighInHint)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, FormaTokens.Spacing.xs)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#Preview {
    PlanReviewSection(state: PlanMissionControlFixtures.loseDashboard.review)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
