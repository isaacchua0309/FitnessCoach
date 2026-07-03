//
//  TodayRecoveryCard.swift
//  Fitness Coach
//
//  Forma — Recovery guidance card for Today Health Intelligence.
//

import SwiftUI

struct TodayRecoveryCard: View {
    let state: TodayRecoveryCardState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                TodayActionCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        TodayHealthIntelligencePhaseBadge(phase: state.phase)

                        Text(state.title)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(TodayHealthIntelligenceCardTypography.body)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                        }

                        guidanceBlock

                        notesBlock
                    }
                    .padding(.vertical, FormaTokens.Spacing.xs)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }

    @ViewBuilder
    private var guidanceBlock: some View {
        VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
            if let trainingGuidance = state.trainingGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: trainingGuidance,
                    iconName: "figure.run",
                    iconColor: FormaTokens.Theme.primary
                )
            }

            if let nutritionGuidance = state.nutritionGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: nutritionGuidance,
                    iconName: "leaf.fill",
                    iconColor: FormaTokens.Theme.secondary
                )
            }
        }
    }

    @ViewBuilder
    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            if let confidenceNote = state.confidenceNote {
                TodayHealthIntelligenceCardNote(text: confidenceNote, tone: .caution)
            }

            if let missingDataNote = state.missingDataNote {
                TodayHealthIntelligenceCardNote(text: missingDataNote)
            }
        }
    }
}

#Preview("Ready") {
    TodayRecoveryCard(state: TodayHealthIntelligencePreviewData.readyDay.recoveryCard)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Low recovery") {
    TodayRecoveryCard(state: TodayHealthIntelligencePreviewData.lowRecoveryDay.recoveryCard)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    TodayRecoveryCard(state: .loading, isLoading: true)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    TodayRecoveryCard(state: TodayHealthIntelligencePreviewData.readyDay.recoveryCard)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .blossomPink)
}
