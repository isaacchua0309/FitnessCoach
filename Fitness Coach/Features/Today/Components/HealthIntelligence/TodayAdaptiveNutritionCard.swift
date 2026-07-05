//
//  TodayAdaptiveNutritionCard.swift
//  Fitness Coach
//
//  Forma — Adaptive nutrition guidance card for Today Health Intelligence.
//

import SwiftUI

struct TodayAdaptiveNutritionCard: View {
    let state: TodayAdaptiveNutritionCardState
    var isLoading: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodayMutedSectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                TodayMetricsCard {
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
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                        }

                        guidanceBlock

                        if let confidenceNote = state.confidenceNote {
                            TodayHealthIntelligenceCardNote(text: confidenceNote, tone: .caution)
                        }
                    }
                    .healthIntelligenceCardInnerPadding()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("today-hi-adaptive-nutrition-card")
        .todayLiveTheme()
    }

    @ViewBuilder
    private var guidanceBlock: some View {
        VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
            if let proteinGuidance = state.proteinGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: proteinGuidance,
                    iconName: "bolt.fill",
                    iconAccent: .primary
                )
            }

            if let calorieGuidance = state.calorieGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: calorieGuidance,
                    iconName: "flame.fill",
                    iconAccent: .tertiary
                )
            }

            if let waterGuidance = state.waterGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: waterGuidance,
                    iconName: "drop.fill",
                    iconAccent: .secondary
                )
            }
        }
    }
}

#Preview("Post workout") {
    TodayAdaptiveNutritionCard(
        state: TodayHealthIntelligencePreviewData.workoutDay.adaptiveNutritionCard!
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Low recovery hydration") {
    TodayAdaptiveNutritionCard(
        state: TodayHealthIntelligencePreviewData.lowRecoveryDay.adaptiveNutritionCard!
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
