//
//  TodayDailyMissionCard.swift
//  Fitness Coach
//
//  Forma — Daily mission synthesis card for Today Health Intelligence.
//

import SwiftUI

struct TodayDailyMissionCard: View {
    let state: TodayDailyMissionState
    var isLoading: Bool = false

    @Environment(\.themePalette) private var palette
    @Environment(\.formaColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        Text(state.headline)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if !state.detailLines.isEmpty {
                            VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
                                ForEach(Array(state.detailLines.enumerated()), id: \.offset) { _, line in
                                    TodayHealthIntelligenceGuidanceRow(
                                        text: line,
                                        iconName: "checkmark.circle.fill",
                                        iconAccent: .tertiary
                                    )
                                }
                            }
                        }

                        if let focusSummary = state.focusSummary {
                            focusSummaryBlock(focusSummary)
                        }
                    }
                    .healthIntelligenceCardInnerPadding()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("today-hi-daily-mission-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private func focusSummaryBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            FormaPlanRowDivider()

            Text(text)
                .font(TodayHealthIntelligenceCardTypography.detail.weight(.medium))
                .foregroundStyle(palette.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.top, TodayLayout.compactSpacing)
    }
}

#Preview("Ready day") {
    TodayDailyMissionCard(state: TodayHealthIntelligencePreviewData.readyDay.dailyMission)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Workout day") {
    TodayDailyMissionCard(state: TodayHealthIntelligencePreviewData.workoutDay.dailyMission)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    TodayDailyMissionCard(state: .loading, isLoading: true)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
