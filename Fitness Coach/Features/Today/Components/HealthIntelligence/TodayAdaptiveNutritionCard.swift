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

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodayMutedSectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                TodayMetricsCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        Text(state.title)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(TodayHealthIntelligenceCardTypography.detail)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
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
        .formaThemeReactive()
    }

    @ViewBuilder
    private var guidanceBlock: some View {
        VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
            if let proteinGuidance = state.proteinGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: proteinGuidance,
                    iconName: "bolt.fill",
                    iconColor: FormaTokens.Theme.primary
                )
            }

            if let calorieGuidance = state.calorieGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: calorieGuidance,
                    iconName: "flame.fill",
                    iconColor: FormaTokens.Color.textTertiary
                )
            }

            if let waterGuidance = state.waterGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: waterGuidance,
                    iconName: "drop.fill",
                    iconColor: FormaTokens.Theme.secondary
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
