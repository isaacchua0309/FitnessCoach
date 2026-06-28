//
//  JourneyLevelSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyLevelSection: View {
    let state: JourneyLevelState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.Level.sectionTitle)

            FitPilotPlanCard {
                if state.hasData {
                    levelContent
                } else {
                    Text(FormaProductCopy.Journey.Level.emptyBody)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var levelContent: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(FormaProductCopy.Journey.Level.levelLabel(state.currentLevel))
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Text(state.levelTitle)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(FormaProductCopy.Journey.Level.levelLabel(state.currentLevel)), \(state.levelTitle)"
            )

            SwiftUI.ProgressView(value: min(max(state.progressPercent / 100, 0), 1))
                .tint(FormaTokens.Color.progress)
                .accessibilityLabel(FormaProductCopy.Journey.Level.xpLabel)
                .accessibilityValue(
                    FormaProductCopy.Journey.Level.xpProgress(
                        current: state.currentXP,
                        required: state.xpRequiredForNextLevel
                    )
                )

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                Text(FormaProductCopy.Journey.Level.xpLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)

                Text(
                    FormaProductCopy.Journey.Level.xpProgress(
                        current: state.currentXP,
                        required: state.xpRequiredForNextLevel
                    )
                )
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
            }
            .accessibilityHidden(true)

            Text(state.xpEarnedExplanation)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("Journey level") {
    ScrollView {
        JourneyLevelSection(state: ProgressPreviewData.journeyLevelActive)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
