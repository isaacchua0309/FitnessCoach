//
//  NutritionEstimateCard.swift
//  Fitness Coach
//
//  Forma — Structured nutrition estimate card for Coach chat.
//

import SwiftUI

struct NutritionEstimateCard: View {
    let state: NutritionEstimateCardState
    var onAction: ((NutritionSuggestedAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            headerSection
            heroCalories
            if state.hasMacros {
                macroRow
            }
            confidenceSection
            if let today = state.todayContext {
                todaySection(today)
            }
            if let summary = state.coachSummary, !summary.isEmpty {
                Text(summary)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let tip = state.coachTip, !tip.isEmpty {
                tipSection(tip)
            }
            if !state.caveats.isEmpty {
                caveatsSection
            }
            if !state.suggestedActions.isEmpty {
                actionsSection
            }
        }
        .padding(CoachDesignTokens.Spacing.md)
        .background {
            FormaCardChrome.background(.bordered)
        }
        .accessibilityElement(children: .combine)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.xs) {
                if let emoji = state.displayEmoji {
                    Text(emoji)
                        .font(CoachDesignTokens.Typography.confirmationTitle)
                }
                Text(state.foodName)
                    .font(CoachDesignTokens.Typography.confirmationTitle)
                    .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let serving = state.servingDescription, !serving.isEmpty {
                Text(serving)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
        }
    }

    private var heroCalories: some View {
        Text(state.caloriesDisplay)
            .font(CoachDesignTokens.Typography.largeTitle)
            .foregroundStyle(CoachDesignTokens.Color.primaryText)
            .accessibilityLabel("Estimated calories, \(state.caloriesDisplay)")
    }

    private var macroRow: some View {
        HStack(spacing: CoachDesignTokens.Spacing.sm) {
            if let protein = state.proteinDisplay {
                macroChip(protein)
            }
            if let carbs = state.carbsDisplay {
                macroChip(carbs)
            }
            if let fat = state.fatDisplay {
                macroChip(fat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroChip(_ text: String) -> some View {
        Text(text)
            .font(CoachDesignTokens.Typography.confirmationMetric)
            .foregroundStyle(CoachDesignTokens.Color.secondaryText)
    }

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(state.confidenceTitle)
                .font(CoachDesignTokens.Typography.hintLabel.weight(.semibold))
                .foregroundStyle(confidenceColor)
            if let subtitle = state.confidenceSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func todaySection(_ today: NutritionEstimateTodayContext) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(FormaProductCopy.Coach.todaySoFarSectionTitle)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(today.caloriesAfterLine)
                .font(CoachDesignTokens.Typography.hint.weight(.medium))
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
            Text(today.caloriesRemainingLine)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            Text(today.proteinLine)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
        }
    }

    private func tipSection(_ tip: String) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Coach tip")
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(tip)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caveatsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            ForEach(Array(state.caveats.enumerated()), id: \.offset) { _, caveat in
                Text(caveat)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CoachDesignTokens.Spacing.xs) {
                ForEach(state.suggestedActions) { action in
                    Button(action.title) {
                        onAction?(action)
                    }
                    .buttonStyle(NutritionEstimateActionChipStyle())
                }
            }
        }
    }

    private var confidenceColor: Color {
        switch state.confidenceLevel {
        case .low:
            CoachDesignTokens.Color.warning
        case .medium, .high:
            CoachDesignTokens.Color.primary
        }
    }
}

private struct NutritionEstimateActionChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
            .foregroundStyle(CoachDesignTokens.Color.primary)
            .padding(.horizontal, CoachDesignTokens.Spacing.sm)
            .padding(.vertical, CoachDesignTokens.Spacing.xs)
            .background(CoachDesignTokens.Color.chipFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(CoachDesignTokens.Color.chipStroke.opacity(0.7), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#if DEBUG
#Preview {
    NutritionEstimateCard(
        state: NutritionEstimateCardState(
            id: UUID(),
            foodName: "Big Mac",
            displayEmoji: "🍔",
            servingDescription: "1 standard burger",
            caloriesDisplay: "550 kcal",
            proteinDisplay: "Protein 25g",
            carbsDisplay: "Carbs 45g",
            fatDisplay: "Fat 30g",
            confidenceTitle: "High confidence",
            confidenceSubtitle: "Known/common food estimate",
            coachSummary: "A Big Mac can fit into today's calories if the rest of the meal stays lighter.",
            coachTip: "Skip fries or choose water to keep this easier to fit.",
            caveats: ["Values may vary slightly by country."],
            todayContext: NutritionEstimateTodayContext(
                caloriesAfterLine: "Calories after this: 1,420 / 2,086 kcal",
                caloriesRemainingLine: "Remaining: 666 kcal",
                proteinLine: "Protein: 112 / 198g"
            ),
            suggestedActions: [
                NutritionSuggestedAction(title: "Log Meal", type: .logMeal),
                NutritionSuggestedAction(title: "Add fries", type: .addCommonSide),
                NutritionSuggestedAction(title: "Estimate another", type: .estimateAnother)
            ],
            sourceType: .branded,
            confidenceLevel: .high,
            hasMacros: true,
            hasTodayContext: true,
            logMealPayload: nil
        )
    )
    .padding()
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
#endif
