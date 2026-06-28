//
//  TodayReadOnlyProgressSection.swift
//  Fitness Coach
//
//  Forma — Macro balance and hydration progress for Today.
//

import SwiftUI

struct TodayReadOnlyProgressSection: View {
    let macros: MacroSummary
    let water: WaterSummary

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodayMutedSectionLabel(title: FormaProductCopy.Today.MacroBalance.sectionTitle)

            TodayMacroBalanceCard(macros: macros)

            TodayMetricsCard {
                waterRow
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var waterRow: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text("Water")
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .layoutPriority(1)
                    .lineLimit(1)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(
                    TodayTargetsFormatter.waterProgress(
                        consumedMl: water.consumedMl,
                        targetMl: water.targetMl
                    )
                )
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .monospacedDigit()
            }

            TodayMetricProgressBar(progress: water.progress)

            Text(waterRemainingText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water")
        .accessibilityValue(waterAccessibilityValue)
    }

    private var waterRemainingText: String {
        if water.targetMl <= 0 {
            return FormaProductCopy.Today.MacroBalance.noTarget
        }
        if water.consumedMl >= water.targetMl {
            return FormaProductCopy.Today.MacroBalance.atTarget
        }
        return "\(water.remainingMl)ml \(FormaProductCopy.Today.MacroBalance.remainingSuffix)"
    }

    private var waterAccessibilityValue: String {
        let progressText = TodayTargetsFormatter.waterProgress(
            consumedMl: water.consumedMl,
            targetMl: water.targetMl
        )
        let percent = Int((min(max(water.progress, 0), 1) * 100).rounded())
        return "\(progressText). \(waterRemainingText). \(percent) percent of target."
    }
}

#Preview("Macro balance") {
    TodayReadOnlyProgressSection(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
            carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
            fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
        ),
        water: WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16)
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Small width") {
    TodayReadOnlyProgressSection(
        macros: TodayPreviewData.state.macroBalance.macroSummary,
        water: TodayPreviewData.state.macroBalance.waterSummary
    )
    .frame(width: 320)
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
