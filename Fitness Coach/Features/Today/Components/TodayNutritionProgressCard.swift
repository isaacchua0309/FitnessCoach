//
//  TodayNutritionProgressCard.swift
//  Fitness Coach
//
//  Forma — Integrated protein, macro, and hydration progress card.
//

import SwiftUI

struct TodayNutritionProgressCard: View {
    let macros: MacroSummary
    let water: WaterSummary
    let calorieSummary: CalorieSummary

    private var display: TodayNutritionProgressCardDisplayModel {
        TodayNutritionProgressFormatting.displayModel(
            macros: macros,
            water: water,
            calorieSummary: calorieSummary
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(display.rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                nutritionRow(row)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.accentLeading))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilitySummary)
    }

    @ViewBuilder
    private func nutritionRow(_ row: TodayNutritionProgressRowDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(row.name)
                    .font(titleFont(for: row.emphasis))
                    .foregroundStyle(titleColor(for: row.emphasis))
                    .layoutPriority(1)
                    .lineLimit(1)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(row.ratioText)
                    .font(valueFont(for: row.emphasis))
                    .foregroundStyle(valueColor(for: row.emphasis))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .monospacedDigit()
            }

            TodayMetricProgressBar(
                progress: row.barProgress,
                subdued: row.emphasis != .primary
            )

            Text(row.remainingText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(remainingTextColor(for: row.displayState))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, row.emphasis == .primary ? FormaTokens.Spacing.sm : TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
    }

    private func titleFont(for emphasis: TodayNutritionRowEmphasis) -> Font {
        switch emphasis {
        case .primary:
            return FormaTokens.Typography.sectionSubtitle.weight(.semibold)
        case .secondary, .standard:
            return FormaTokens.Typography.caption.weight(.medium)
        }
    }

    private func valueFont(for emphasis: TodayNutritionRowEmphasis) -> Font {
        switch emphasis {
        case .primary:
            return FormaTokens.Typography.sectionSubtitle
        case .secondary, .standard:
            return FormaTokens.Typography.caption
        }
    }

    private func titleColor(for emphasis: TodayNutritionRowEmphasis) -> Color {
        switch emphasis {
        case .primary:
            return FormaTokens.Color.textPrimary
        case .secondary, .standard:
            return FormaTokens.Color.textSecondary
        }
    }

    private func valueColor(for emphasis: TodayNutritionRowEmphasis) -> Color {
        switch emphasis {
        case .primary:
            return FormaTokens.Color.textPrimary
        case .secondary, .standard:
            return FormaTokens.Color.textSecondary
        }
    }

    private func remainingTextColor(for state: TodayNutritionDisplayState) -> Color {
        switch state {
        case .overTarget, .missingTarget:
            FormaTokens.Color.textTertiary
        case .nearTarget, .belowTarget:
            FormaTokens.Color.textSecondary
        }
    }
}

#Preview("Nutrition progress") {
    TodayNutritionProgressCard(
        macros: TodayPreviewData.state.macroHydration.macroSummary,
        water: TodayPreviewData.state.macroHydration.waterSummary,
        calorieSummary: TodayPreviewData.state.mission.calorieSummary
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("No calorie target") {
    TodayNutritionProgressCard(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
            carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
            fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
        ),
        water: WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16),
        calorieSummary: CalorieSummary(
            consumed: 710,
            target: 0,
            remaining: 0,
            progress: 0,
            isOverTarget: false
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
