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
    var includesDedicatedWaterCard: Bool = true

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var display: TodayNutritionProgressCardDisplayModel {
        TodayNutritionProgressFormatting.displayModel(
            macros: macros,
            water: water,
            calorieSummary: calorieSummary,
            includesDedicatedWaterCard: includesDedicatedWaterCard
        )
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: 0) {
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
        .background {
            FormaCardChrome.background(.accentLeading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilitySummary)
        .todayLiveTheme()
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
                    .foregroundStyle(valueColor(for: row.emphasis, state: row.displayState))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .monospacedDigit()
            }

            TodayMetricProgressBar(
                progress: row.barProgress,
                height: progressBarHeight(for: row.emphasis),
                subdued: row.emphasis != .primary,
                isOverTarget: row.displayState == .overTarget
            )

            Text(row.remainingText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(remainingTextColor(for: row.displayState))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, row.emphasis == .primary ? FormaTokens.Spacing.sm : TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
    }

    private func progressBarHeight(for emphasis: TodayNutritionRowEmphasis) -> CGFloat {
        emphasis == .primary
            ? TodayLayout.metricsProgressHeightPrimary
            : TodayLayout.metricsProgressHeight
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
            return theme.primaryText
        case .secondary, .standard:
            return theme.secondaryText
        }
    }

    private func valueColor(for emphasis: TodayNutritionRowEmphasis) -> Color {
        switch emphasis {
        case .primary:
            return theme.primaryText
        case .secondary, .standard:
            return theme.secondaryText
        }
    }

    private func valueColor(
        for emphasis: TodayNutritionRowEmphasis,
        state: TodayNutritionDisplayState
    ) -> Color {
        if state == .overTarget {
            return theme.destructive
        }
        return valueColor(for: emphasis)
    }

    private func remainingTextColor(for state: TodayNutritionDisplayState) -> Color {
        switch state {
        case .overTarget:
            theme.destructive.opacity(0.9)
        case .missingTarget:
            theme.tertiaryText
        case .nearTarget, .belowTarget:
            theme.secondaryText
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

#Preview("Over target") {
    TodayNutritionProgressCard(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 185, target: 170, remaining: 0, progress: 1.09),
            carbs: MacroProgress(consumed: 220, target: 160, remaining: 0, progress: 1.38),
            fat: MacroProgress(consumed: 72, target: 60, remaining: 0, progress: 1.2)
        ),
        water: WaterSummary(consumedMl: 3_800, targetMl: 3_500, remainingMl: 0, progress: 1.09),
        calorieSummary: CalorieSummary(
            consumed: 2_050,
            target: 1_800,
            remaining: 0,
            progress: 1.14,
            isOverTarget: true
        )
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
