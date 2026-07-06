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
        return MainTabCard(style: .accentLeading, compact: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(display.rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        FormaPlanRowDivider()
                    }
                    nutritionRow(row)
                }
            }
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

#if DEBUG
#Preview("Nutrition progress") {
    TodayNutritionProgressCard(
        macros: TodayPreviewData.state.macroHydration.macroSummary,
        water: TodayPreviewData.state.macroHydration.waterSummary,
        calorieSummary: TodayPreviewData.state.mission.calorieSummary
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
