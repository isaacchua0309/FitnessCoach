//
//  GeneratedPlanSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only generated plan summary for onboarding.
//

import SwiftUI

struct GeneratedPlanSummaryCard: View {
    let plan: CalorieTargetResult
    var pacePreview: WeightLossPacePreviewModel?
    var paceLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            heroTargets

            if let warningMessage = planWarningMessage {
                OnboardingWarningBanner(message: warningMessage)
            }

            if let pacePreview, pacePreview.isSaveable, paceLabel != nil {
                paceSummaryCard(pacePreview)
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
                sectionHeader("Behind your numbers", icon: "function")
                planRow("BMR", OnboardingFormatter.kcal(plan.estimatedBMR))
                planRow("TDEE", OnboardingFormatter.kcal(plan.estimatedTDEE))
                planRow("Daily deficit", OnboardingFormatter.kcal(plan.estimatedDailyDeficit))
                if let paceLabel {
                    planRow("Pace", paceLabel)
                }
                if let weeklyLoss = OnboardingFormatter.weeklyLoss(plan.targets.expectedWeeklyWeightLossKg) {
                    planRow("Expected weekly loss", weeklyLoss)
                }
            }
            .onboardingCard()

            OnboardingInfoCard(
                title: "Start here, then adapt",
                message: FormaProductCopy.Onboarding.planBaselineMessage,
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    private var planWarningMessage: String? {
        if let warning = pacePreview?.warningMessage {
            return warning
        }
        if plan.isAggressive {
            return WeightLossPacePreviewBuilder.paceWarningCopy
        }
        return nil
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

    private func paceSummaryCard(_ preview: WeightLossPacePreviewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your pace", icon: "speedometer")

            if let safety = preview.safetyDisplay {
                Text(OnboardingFormatter.safetyDisplay(safety))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.warning)
            }

            if let summary = preview.deficitSummaryLine {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let weekly = preview.weeklyLossKg,
               let monthly = preview.monthlyLossKg {
                planRow("Weekly", OnboardingFormatter.weeklyLoss(weekly) ?? "")
                planRow("Monthly", OnboardingFormatter.monthlyLoss(monthly))
                if let deficit = preview.dailyDeficitKcal {
                    planRow("Deficit", "\(deficit) kcal/day")
                }
            }
        }
        .onboardingCard()
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
    GeneratedPlanSummaryCard(
        plan: OnboardingPreviewData.generatedPlan,
        pacePreview: OnboardingPreviewData.formState.pacePreview(),
        paceLabel: "Moderate"
    )
    .padding()
}
