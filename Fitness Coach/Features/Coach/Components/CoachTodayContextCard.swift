//
//  CoachTodayContextCard.swift
//  Fitness Coach
//
//  Forma — Compact today snapshot shown above Coach quick actions.
//

import SwiftUI

struct CoachTodayContextCard: View {
    let state: CoachTodayContextState

    var body: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
                contextSection(
                    title: FormaProductCopy.Coach.todaySoFarSectionTitle,
                    lines: [state.caloriesLine, state.proteinLine, state.waterLine]
                )

                CoachContextDivider()

                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    Text(FormaProductCopy.Coach.suggestedNextSectionTitle)
                        .font(CoachDesignTokens.Typography.hintLabel)
                        .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.4)

                    Text(state.suggestedFocus)
                        .font(CoachDesignTokens.Typography.hint)
                        .foregroundStyle(CoachDesignTokens.Color.textLegal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func contextSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(title)
                .font(CoachDesignTokens.Typography.hintLabel)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.4)

            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(
                            index == 0
                                ? CoachDesignTokens.Typography.hint.weight(.medium)
                                : CoachDesignTokens.Typography.hint
                        )
                        .foregroundStyle(
                            index == 0
                                ? CoachDesignTokens.Color.primaryText
                                : CoachDesignTokens.Color.secondaryText
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var accessibilitySummary: String {
        """
        \(FormaProductCopy.Coach.todaySoFarSectionTitle). \
        \(state.caloriesLine). \(state.proteinLine). \(state.waterLine). \
        \(FormaProductCopy.Coach.suggestedNextSectionTitle): \(state.suggestedFocus)
        """
    }
}

private struct CoachContextDivider: View {
    var body: some View {
        Rectangle()
            .fill(CoachDesignTokens.Color.border.opacity(0.65))
            .frame(height: 1)
            .padding(.vertical, CoachDesignTokens.Spacing.xxs)
    }
}

#Preview {
    CoachTodayContextCard(
        state: CoachTodayContextState(
            caloriesLine: "0 eaten · 2,249 target",
            proteinLine: "Protein 0 / 180 g",
            waterLine: "Water 0 / 3150 ml",
            suggestedFocus: FormaProductCopy.Today.focusProteinLow
        )
    )
    .padding()
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
