//
//  JourneyMilestonesSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMilestonesSection: View {
    let state: JourneyMilestoneState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .featured) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                        if !state.icon.isEmpty {
                            JourneyMilestoneIcon(symbol: state.icon)
                        }

                        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                            Text(state.header)
                                .font(JourneyTypography.cardSupporting.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.4)
                                .accessibilityHidden(true)

                            Text(state.title)
                                .font(JourneyTypography.cardHeadline)
                                .foregroundStyle(FormaTokens.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(state.progressText)
                        .font(JourneyTypography.metricValue)
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .accessibilityHidden(true)

                    JourneyProgressBar(progress: state.progressFraction)
                        .accessibilityLabel(state.title)
                        .accessibilityValue(
                            FormaProductCopy.Journey.Milestones.Accessibility.progressPercent(
                                Int((state.progressFraction * 100).rounded())
                            )
                        )

                    Text(state.rewardCopy)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }
}

// MARK: - Previews

#Preview("New user") {
    JourneyMilestonesSection(state: JourneyPreviewData.brandNewUser.milestone)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Active progress") {
    JourneyMilestonesSection(state: JourneyPreviewData.strongMomentum.milestone)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
