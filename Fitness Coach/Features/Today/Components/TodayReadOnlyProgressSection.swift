//
//  TodayReadOnlyProgressSection.swift
//  Fitness Coach
//
//  Forma — Integrated nutrition progress for Today.
//

import SwiftUI

struct TodayReadOnlyProgressSection: View {
    let macros: MacroSummary
    let water: WaterSummary
    let calorieSummary: CalorieSummary

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            SectionLabel(title: FormaProductCopy.Today.MacroBalance.sectionTitle, style: .muted)

            TodayNutritionProgressCard(
                macros: macros,
                water: water,
                calorieSummary: calorieSummary
            )
        }
        .accessibilityElement(children: .contain)
        .todayLiveTheme()
    }
}

#Preview("Nutrition") {
    TodayReadOnlyProgressSection(
        macros: MacroSummary(
            protein: MacroProgress(consumed: 92, target: 180, remaining: 88, progress: 0.51),
            carbs: MacroProgress(consumed: 120, target: 220, remaining: 100, progress: 0.55),
            fat: MacroProgress(consumed: 40, target: 65, remaining: 25, progress: 0.62)
        ),
        water: WaterSummary(consumedMl: 500, targetMl: 3_150, remainingMl: 2_650, progress: 0.16),
        calorieSummary: CalorieSummary(
            consumed: 710,
            target: 1_800,
            remaining: 1_090,
            progress: 0.39,
            isOverTarget: false
        )
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
