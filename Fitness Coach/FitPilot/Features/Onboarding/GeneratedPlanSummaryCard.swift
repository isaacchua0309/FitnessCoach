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
        VStack(alignment: .leading, spacing: 20) {
            if plan.isAggressive || plan.warning != nil {
                Label(
                    "This target is aggressive. Pay attention to energy, hunger, sleep, and training performance. You can always adjust it later.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Estimates")
                    .font(.headline)
                planRow("BMR", OnboardingFormatter.kcal(plan.estimatedBMR))
                planRow("TDEE", OnboardingFormatter.kcal(plan.estimatedTDEE))
                planRow("Daily deficit", OnboardingFormatter.kcal(plan.estimatedDailyDeficit))
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Targets")
                    .font(.headline)
                planRow("Calories", OnboardingFormatter.kcal(plan.targets.calorieTarget))
                planRow("Protein", OnboardingFormatter.grams(plan.targets.proteinTarget))
                planRow("Carbs", OnboardingFormatter.grams(plan.targets.carbTarget))
                planRow("Fat", OnboardingFormatter.grams(plan.targets.fatTarget))
                planRow("Water", OnboardingFormatter.ml(plan.targets.waterTargetMl))
                planRow(
                    "Aggressiveness",
                    OnboardingFormatter.aggressiveness(plan.targets.aggressiveness)
                )
                if let weeklyLoss = OnboardingFormatter.weeklyLoss(plan.targets.expectedWeeklyWeightLossKg) {
                    planRow("Expected weekly loss", weeklyLoss)
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func planRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

#Preview {
    GeneratedPlanSummaryCard(plan: OnboardingPreviewData.generatedPlan)
        .padding()
}
