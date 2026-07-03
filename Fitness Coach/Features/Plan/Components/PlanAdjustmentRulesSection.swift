//
//  PlanAdjustmentRulesSection.swift
//  Fitness Coach
//
//  Forma — When to Adjust guidance card.
//

import SwiftUI

struct PlanAdjustmentRulesSection: View {
    let state: AdjustmentRulesState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(state.reviewHeading)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .accessibilityHidden(true)

                    ForEach(state.rules) { rule in
                        ruleRow(rule.text)
                    }

                    if let trendHint = state.trendHint {
                        Text(trendHint)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, FormaTokens.Spacing.xs)
                            .accessibilityHidden(true)
                    }

                    if let aggressivePlanNote = state.aggressivePlanNote {
                        Text(aggressivePlanNote)
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

    private func ruleRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text("•")
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .frame(width: 14, alignment: .leading)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PlanAdjustmentRulesSection(state: PlanMissionControlFixtures.loseDashboard.adjustmentRules)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
