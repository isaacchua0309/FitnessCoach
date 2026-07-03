//
//  TodayMissionHero.swift
//  Fitness Coach
//
//  Forma — Today's Mission hero: calories remaining, protein gap, and status.
//

import SwiftUI

struct TodayMissionHero: View {
    let mission: TodayMissionState
    let proteinProgress: MacroProgress
    let mealsEmptyKind: TodayMealsEmptyKind
    let onLogMeal: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    private var display: TodayMissionHeroDisplayModel {
        TodayMissionHeroFormatter.displayModel(
            mission: mission,
            proteinProgress: proteinProgress,
            mealsEmptyKind: mealsEmptyKind
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Mission.sectionTitle)

            metricsBlock

            if display.showsLogMealCTA {
                FormaQuickActionChip(
                    title: FormaProductCopy.Today.EmptyState.logMealAction,
                    action: onLogMeal,
                    accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
                )
                .padding(.top, FormaTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
            Text(display.primaryMetricLabel)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)

            Text(display.primaryMetricValue)
                .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    display.isOverTarget
                        ? FormaTokens.Color.destructive
                        : FormaTokens.Color.textPrimary
                )
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            SwiftUI.ProgressView(value: display.progress)
                .tint(
                    display.isOverTarget
                        ? FormaTokens.Color.destructive
                        : FormaTokens.Color.progress
                )

            Text(display.statusLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityLabel)
    }
}

#Preview("New profile") {
    TodayMissionHero(
        mission: TodayPreviewData.emptyDay.mission,
        proteinProgress: TodayPreviewData.emptyDay.macroBalance.macroSummary.protein,
        mealsEmptyKind: .newProfileNoMeals,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial day") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        proteinProgress: TodayPreviewData.partialDay.macroBalance.macroSummary.protein,
        mealsEmptyKind: .hasMeals,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Over target") {
    TodayMissionHero(
        mission: TodayPreviewData.overTargetDay.mission,
        proteinProgress: TodayPreviewData.overTargetDay.macroBalance.macroSummary.protein,
        mealsEmptyKind: .hasMeals,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
