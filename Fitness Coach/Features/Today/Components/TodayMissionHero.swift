//
//  TodayMissionHero.swift
//  Fitness Coach
//
//  Forma — Today's Mission hero: one dominant calorie number and supporting context.
//

import SwiftUI

struct TodayMissionHero: View {
    let mission: TodayMissionState
    let onLogMeal: () -> Void
    var onViewed: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: mission.sectionTitle)

            metricsBlock

            if mission.showsLogMealCTA {
                FormaQuickActionChip(
                    title: FormaProductCopy.Today.Mission.logMealCTA,
                    action: onLogMeal,
                    accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
                )
                .padding(.top, FormaTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            onViewed?()
        }
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
            Text(mission.primaryValue)
                .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(primaryValueColor)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            supportingLinesBlock

            if !mission.statusLine.isEmpty {
                Text(mission.statusLine)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mission.accessibilityLabel)
    }

    private var supportingLinesBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            supportingLine(mission.goalLine)
            supportingLine(mission.consumedLine)
            supportingLine(mission.proteinRemainingLine)
        }
        .padding(.top, TodayLayout.compactSpacing)
    }

    private func supportingLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryValueColor: Color {
        switch mission.primaryKind {
        case .over:
            return FormaTokens.Color.destructive
        case .remaining, .targetReached, .missingTarget:
            return FormaTokens.Color.textPrimary
        }
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
