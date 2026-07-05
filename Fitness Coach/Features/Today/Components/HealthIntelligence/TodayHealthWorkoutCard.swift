//
//  TodayHealthWorkoutCard.swift
//  Fitness Coach
//
//  Forma — Workout summary card for Today Health Intelligence.
//

import SwiftUI

struct TodayHealthWorkoutCard: View {
    let state: TodayHealthWorkoutCardState
    var isLoading: Bool = false

    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodayMutedSectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        Text(state.title)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(TodayHealthIntelligenceCardTypography.detail)
                                .foregroundStyle(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                        }

                        tipsBlock
                    }
                    .healthIntelligenceCardInnerPadding()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("today-hi-workout-card")
        .todayLiveTheme()
    }

    @ViewBuilder
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
            if let nutritionTip = state.nutritionTip {
                TodayHealthIntelligenceGuidanceRow(
                    text: nutritionTip,
                    iconName: "fork.knife",
                    iconAccent: .primary
                )
            }

            if let hydrationTip = state.hydrationTip {
                TodayHealthIntelligenceGuidanceRow(
                    text: hydrationTip,
                    iconName: "drop.fill",
                    iconAccent: .secondary
                )
            }
        }
    }
}

#Preview("Empty workout history") {
    TodayHealthWorkoutCard(
        state: TodayHealthIntelligencePreviewData.noWorkoutHistory.workoutCard!
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Workout complete") {
    TodayHealthWorkoutCard(
        state: TodayHealthIntelligencePreviewData.workoutDay.workoutCard!
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Emerald Green") {
    TodayHealthWorkoutCard(
        state: TodayHealthIntelligencePreviewData.workoutDay.workoutCard!
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .emeraldGreen)
}
