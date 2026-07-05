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

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.formaColors) private var colors

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                TodayActionCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        TodayHealthIntelligencePhaseBadge(phase: state.phase)

                        Text(state.title)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if let subtitle = state.subtitle {
                            Text(subtitle)
                                .font(TodayHealthIntelligenceCardTypography.body)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                        }

                        guidanceBlock

                        notesBlock

                        if let staleDataLabel = state.staleDataLabel {
                            TodayHealthIntelligenceCardNote(text: staleDataLabel)
                        }
                    }
                    .healthIntelligenceCardInnerPadding()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("today-hi-recovery-card")
    }

    @ViewBuilder
    private var guidanceBlock: some View {
        VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.guidanceSpacing) {
            if let trainingGuidance = state.trainingGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: trainingGuidance,
                    iconName: "figure.run",
                    iconAccent: .primary
                )
            }

            if let nutritionGuidance = state.nutritionGuidance {
                TodayHealthIntelligenceGuidanceRow(
                    text: nutritionGuidance,
                    iconName: "leaf.fill",
                    iconAccent: .secondary
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
