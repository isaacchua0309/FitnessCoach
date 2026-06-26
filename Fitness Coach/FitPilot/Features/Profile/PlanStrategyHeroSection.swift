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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(state.strategyName)
                            .font(.title.weight(.bold))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Button("Edit", action: onEditPlan)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(OnboardingTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.calorieTargetText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.primaryText)
                        Text(state.proteinTargetText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(OnboardingTheme.secondaryText)
                        Text(state.trainingFrequencyText)
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.tertiaryText)
                    }

                    Text(state.startedLabel)
                        .font(.caption)
                        .foregroundStyle(OnboardingTheme.tertiaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        PlanSectionLabel(title: "Coach")
                        Text(state.coachSummary)
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
