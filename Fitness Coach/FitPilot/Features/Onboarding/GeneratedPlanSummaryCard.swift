//
//  GeneratedPlanSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only generated plan summary for onboarding.
//

import SwiftUI

struct GeneratedPlanSummaryCard: View {
    let plan: CalorieTargetResult

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            heroTargets

            if plan.isAggressive || plan.warning != nil {
                OnboardingWarningBanner(
                    message: plan.warning
                        ?? "This target is aggressive. Watch energy, hunger, sleep, and training performance."
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Daily targets", icon: "target")
                planRow("Protein", OnboardingFormatter.grams(plan.targets.proteinTarget))
                planRow("Carbs", OnboardingFormatter.grams(plan.targets.carbTarget))
                planRow("Fat", OnboardingFormatter.grams(plan.targets.fatTarget))
                planRow("Water", OnboardingFormatter.ml(plan.targets.waterTargetMl))
            }
            .onboardingCard()

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Plan math", icon: "function")
                planRow("BMR", OnboardingFormatter.kcal(plan.estimatedBMR))
                planRow("TDEE", OnboardingFormatter.kcal(plan.estimatedTDEE))
                planRow("Daily deficit", OnboardingFormatter.kcal(plan.estimatedDailyDeficit))
                planRow(
                    "Aggressiveness",
                    OnboardingFormatter.aggressiveness(plan.targets.aggressiveness)
                )
                if let weeklyLoss = OnboardingFormatter.weeklyLoss(plan.targets.expectedWeeklyWeightLossKg) {
                    planRow("Expected weekly loss", weeklyLoss)
                }
            }
            .onboardingCard()

            OnboardingInfoCard(
                title: "Start here, then adapt",
                message: "Your first week is a baseline. Use daily logs and weigh-ins so FitPilot can make better adjustments.",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    private var heroTargets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)

            Text(OnboardingFormatter.kcal(plan.targets.calorieTarget))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            if let weeklyLoss = OnboardingFormatter.weeklyLoss(plan.targets.expectedWeeklyWeightLossKg) {
                Text("\(weeklyLoss) expected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(OnboardingTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard(selected: true)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(OnboardingTheme.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func planRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    GeneratedPlanSummaryCard(plan: OnboardingPreviewData.generatedPlan)
        .padding()
}
