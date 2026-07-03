//
//  NutritionComparisonCard.swift
//  Fitness Coach
//
//  Forma — Compact side-by-side nutrition comparison for Coach chat.
//

import SwiftUI

struct NutritionComparisonCard: View {
    let state: NutritionComparisonCardState
    var onAction: ((NutritionSuggestedAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            comparisonGrid
            if let pick = state.coachPick, !pick.isEmpty {
                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    Text("Coach pick")
                        .font(CoachDesignTokens.Typography.hintLabel)
                        .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(pick)
                        .font(CoachDesignTokens.Typography.hint)
                        .foregroundStyle(CoachDesignTokens.Color.textLegal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !state.suggestedActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CoachDesignTokens.Spacing.xs) {
                        ForEach(state.suggestedActions) { action in
                            Button(action.title) {
                                onAction?(action)
                            }
                            .buttonStyle(NutritionComparisonActionChipStyle())
                        }
                    }
                }
            }
        }
        .padding(CoachDesignTokens.Spacing.md)
        .background {
            FormaCardChrome.background(.bordered)
        }
        .accessibilityElement(children: .combine)
    }

    private var comparisonGrid: some View {
        HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.md) {
            comparisonColumn(
                item: state.leftItem,
                calories: state.leftCaloriesDisplay,
                protein: state.leftProteinDisplay,
                fat: state.leftFatDisplay
            )
            comparisonColumn(
                item: state.rightItem,
                calories: state.rightCaloriesDisplay,
                protein: state.rightProteinDisplay,
                fat: state.rightFatDisplay
            )
        }
    }

    private func comparisonColumn(
        item: NutritionComparisonItem,
        calories: String,
        protein: String?,
        fat: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            HStack(spacing: CoachDesignTokens.Spacing.xxs) {
                if let emoji = item.displayEmoji {
                    Text(emoji)
                }
                Text(item.foodName)
                    .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
                    .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(calories)
                .font(CoachDesignTokens.Typography.confirmationValue)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
            if let protein {
                Text(protein)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            }
            if let fat {
                Text(fat)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NutritionComparisonActionChipStyle: ButtonStyle {
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
    NutritionComparisonCard(
        state: NutritionComparisonCardState(
            id: UUID(),
            leftItem: NutritionComparisonItem(foodName: "Big Mac", displayEmoji: "🍔"),
            rightItem: NutritionComparisonItem(foodName: "McSpicy", displayEmoji: "🍔"),
            leftCaloriesDisplay: "550 kcal",
            rightCaloriesDisplay: "540 kcal",
            leftProteinDisplay: "25g protein",
            rightProteinDisplay: "27g protein",
            leftFatDisplay: "30g fat",
            rightFatDisplay: "29g fat",
            coachPick: "Choose McSpicy if you want slightly more protein.",
            suggestedActions: [
                NutritionSuggestedAction(title: "Estimate another", type: .estimateAnother)
            ]
        )
    )
    .padding()
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
#endif
