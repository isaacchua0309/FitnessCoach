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
    let mealsEmpty: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    private var display: TodayMissionHeroDisplayModel {
        TodayMissionHeroFormatter.displayModel(
            mission: mission,
            proteinProgress: proteinProgress,
            mealsEmpty: mealsEmpty
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Mission.sectionTitle)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                Text(display.primaryMetricLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .accessibilityHidden(true)

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
                    .accessibilityHidden(true)

                SwiftUI.ProgressView(value: display.progress)
                    .tint(
                        display.isOverTarget
                            ? FormaTokens.Color.destructive
                            : FormaTokens.Color.accent
                    )
                    .accessibilityHidden(true)

                subMetricsBlock

                Text(display.statusLine)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityLabel)
    }

    private var subMetricsBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            subMetricRow(display.goalLine)
            subMetricRow(display.consumedLine)
            subMetricRow(display.proteinLine)
        }
        .padding(.top, TodayLayout.compactSpacing)
    }

    private func subMetricRow(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Partial day") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        proteinProgress: TodayPreviewData.partialDay.macroBalance.macroSummary.protein,
        mealsEmpty: false
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Empty day") {
    TodayMissionHero(
        mission: TodayPreviewData.emptyDay.mission,
        proteinProgress: TodayPreviewData.emptyDay.macroBalance.macroSummary.protein,
        mealsEmpty: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Over target") {
    TodayMissionHero(
        mission: TodayPreviewData.overTargetDay.mission,
        proteinProgress: TodayPreviewData.overTargetDay.macroBalance.macroSummary.protein,
        mealsEmpty: false
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Small phone") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        proteinProgress: TodayPreviewData.partialDay.macroBalance.macroSummary.protein,
        mealsEmpty: false
    )
    .frame(width: 320)
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
