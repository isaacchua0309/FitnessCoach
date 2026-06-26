//
//  PlanStrategyHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanStrategyHeroSection: View {
    let state: PlanStrategyState
    let onEditPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Current strategy")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                        Text(state.strategyName)
                            .font(FormaTokens.Typography.screenTitle.weight(.bold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Button("Edit", action: onEditPlan)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.accent)
                            .buttonStyle(.plain)
                            .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                            .accessibilityLabel("Edit plan")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.calorieTargetText)
                            .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                        Text(state.proteinTargetText)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                        Text(state.trainingFrequencyText)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                    }

                    Text(state.startedLabel)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)

                    VStack(alignment: .leading, spacing: 4) {
                        PlanSectionLabel(title: "Coach")
                        Text(state.coachSummary)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
