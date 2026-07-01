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

    @Environment(\.onboardingPlanRevealIsCompactHeight) private var isCompactHeight
    @Environment(\.onboardingPlanRevealIsCompactWidth) private var isCompactWidth
    @Environment(\.onboardingPlanRevealActionCardsAreSideBySide) private var actionCardsAreSideBySide
    @Environment(\.onboardingPlanRevealContentDensity) private var contentDensity

    private var usesStackedFuelMetrics: Bool {
        isCompactWidth || actionCardsAreSideBySide || isCompactHeight
    }

    private var showsSecondaryMacros: Bool {
        !secondaryMacroRows.isEmpty && !isCompactHeight && contentDensity != .tight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            OnboardingPlanRevealSectionHeader(title: sectionTitle)

            Text(explanationLine)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(contentDensity == .tight ? 1 : (isCompactHeight ? 1 : 2))
                .minimumScaleFactor(0.75)

            fuelMetricsLayout

            if showsSecondaryMacros {
                fuelMetricsRow(secondaryMacroRows)
            }
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .subtle) }
        .onboardingPlanRevealEntrance(.nutrition)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var fuelMetricsLayout: some View {
        let rows = [
            OnboardingPlanRevealMetricRow(label: "Cal", value: calorieLabel),
            OnboardingPlanRevealMetricRow(label: "Protein", value: proteinLabel),
            OnboardingPlanRevealMetricRow(label: "Water", value: waterLabel)
        ]

        if usesStackedFuelMetrics {
            VStack(spacing: FormaTokens.Spacing.xs) {
                ForEach(rows) { row in
                    fuelMetric(label: row.label, value: row.value)
                }
            }
        } else {
            fuelMetricsRow(rows)
        }
    }

    @ViewBuilder
    private func fuelMetricsRow(_ rows: [OnboardingPlanRevealMetricRow]) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ForEach(rows) { row in
                fuelMetric(label: row.label, value: row.value)
            }
        }
    }

    private func fuelMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.savePlanFooterBottomInset) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .padding(.horizontal, FormaTokens.Spacing.xs)
        .padding(.vertical, OnboardingLayout.savePlanFooterBottomInset)
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
