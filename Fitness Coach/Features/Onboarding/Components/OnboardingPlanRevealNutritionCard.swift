//
//  OnboardingPlanRevealNutritionCard.swift
//  Fitness Coach
//
//  Forma — Daily fuel targets for plan reveal (supporting, not hero).
//

import SwiftUI

struct OnboardingPlanRevealNutritionCard: View {
    let sectionTitle: String
    let explanationLine: String
    let calorieLabel: String
    let proteinLabel: String
    let waterLabel: String
    let secondaryMacroRows: [OnboardingPlanRevealMetricRow]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(sectionTitle.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .tracking(0.4)
                .accessibilityAddTraits(.isHeader)

            Text(explanationLine)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: FormaTokens.Spacing.xs) {
                fuelMetric(label: "Cal", value: calorieLabel)
                fuelMetric(label: "Protein", value: proteinLabel)
                fuelMetric(label: "Water", value: waterLabel)
            }

            if !secondaryMacroRows.isEmpty {
                HStack(spacing: FormaTokens.Spacing.xs) {
                    ForEach(secondaryMacroRows) { row in
                        fuelMetric(label: row.label, value: row.value)
                    }
                }
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func fuelMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .lineLimit(1)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.horizontal, FormaTokens.Spacing.xs)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surface.opacity(0.65))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private var accessibilityLabel: String {
        let secondary = secondaryMacroRows.map { "\($0.label) \($0.value)" }.joined(separator: ", ")
        var parts = [
            sectionTitle,
            explanationLine,
            "Calories \(calorieLabel)",
            "Protein \(proteinLabel)",
            "Water \(waterLabel)"
        ]
        if !secondary.isEmpty {
            parts.append(secondary)
        }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealNutritionCard(
        sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.dailyFuelTitle,
        explanationLine: FormaProductCopy.Onboarding.V2.PlanReveal.cutCalorieExplanation,
        calorieLabel: "2,000 kcal",
        proteinLabel: "150 g",
        waterLabel: "2,800 ml",
        secondaryMacroRows: [
            OnboardingPlanRevealMetricRow(label: "Carbs", value: "200 g"),
            OnboardingPlanRevealMetricRow(label: "Fat", value: "60 g")
        ]
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
