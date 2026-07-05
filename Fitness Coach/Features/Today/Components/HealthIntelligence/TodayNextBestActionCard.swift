//
//  TodayNextBestActionCard.swift
//  Fitness Coach
//
//  Forma — Health Intelligence next best action card for Today.
//

import SwiftUI

struct TodayNextBestActionCard: View {
    let state: TodayHealthNextBestActionState
    var isLoading: Bool = false
    var onAction: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.formaColors) private var colors

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: state.sectionTitle)

            TodayHealthIntelligenceLoadingCard(isLoading: isLoading) {
                TodayActionCard {
                    VStack(alignment: .leading, spacing: TodayHealthIntelligenceCardSupport.cardContentSpacing) {
                        Text(state.title)
                            .font(TodayHealthIntelligenceCardTypography.headline)
                            .foregroundStyle(colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        if let message = state.message {
                            Text(message)
                                .font(TodayHealthIntelligenceCardTypography.body)
                                .foregroundStyle(colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                        }

                        if let actionTitle = resolvedActionTitle, let onAction {
                            FormaQuickActionChip(
                                title: actionTitle,
                                action: onAction,
                                accessibilityHint: FormaProductCopy.Today.NextAction.primaryButtonHint
                            )
                            .padding(.top, TodayLayout.compactSpacing)
                            .accessibilityLabel(actionTitle)
                        }
                    }
                    .healthIntelligenceCardInnerPadding()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("today-hi-next-best-action-card")
    }

    private var resolvedActionTitle: String? {
        if let ctaTitle = state.ctaTitle, !ctaTitle.isEmpty {
            return ctaTitle
        }

        switch state.destination {
        case .logMeal:
            return FormaProductCopy.Today.NextAction.ctaLogMeal
        case .addWater:
            return FormaProductCopy.Today.NextAction.ctaAddWater
        case .askCoach:
            return state.title
        case .viewRecovery:
            return state.title
        case .logWeight:
            return FormaProductCopy.Today.NextAction.ctaLogWeight
        case .connectHealth:
            return FormaProductCopy.Today.NextAction.ctaConnectHealth
        case .none:
            return nil
        }
    }
}

#Preview("Log protein") {
    TodayNextBestActionCard(
        state: TodayHealthIntelligencePreviewData.workoutDay.nextBestAction,
        onAction: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Connect health") {
    TodayNextBestActionCard(
        state: TodayHealthIntelligencePreviewData.noHealthData.nextBestAction,
        onAction: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Low recovery") {
    TodayNextBestActionCard(
        state: TodayHealthIntelligencePreviewData.lowRecoveryDay.nextBestAction,
        onAction: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
