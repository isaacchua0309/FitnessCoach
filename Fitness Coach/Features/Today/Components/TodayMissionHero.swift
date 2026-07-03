//
//  TodayMissionHero.swift
//  Fitness Coach
//
//  Forma — Today's Mission hero: calories remaining and contextual status.
//

import SwiftUI

struct TodayMissionHero: View {
    let mission: TodayMissionState
    let onLogMeal: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: mission.sectionTitle)

            metricsBlock

            if mission.showsLogMealCTA {
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
            Text(mission.primaryMetricLabel)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)

            Text(mission.primaryMetricValue)
                .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(
                    mission.phase == .overTarget
                        ? FormaTokens.Color.destructive
                        : FormaTokens.Color.textPrimary
                )
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            SwiftUI.ProgressView(value: mission.progress)
                .tint(
                    mission.phase == .overTarget
                        ? FormaTokens.Color.destructive
                        : FormaTokens.Color.progress
                )

            Text(mission.statusLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mission.accessibilityLabel)
    }
}

#if DEBUG
#Preview("New profile") {
    TodayMissionHero(
        mission: TodayPreviewData.emptyDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial day") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Over target") {
    TodayMissionHero(
        mission: TodayPreviewData.overTargetDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
