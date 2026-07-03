//
//  JourneyMilestonesSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMilestonesSection: View {
    let state: JourneyMilestoneState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                        Text(state.icon)
                            .font(.system(size: 28))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                            Text(state.header)
                                .font(FormaTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .textCase(.uppercase)
                                .accessibilityHidden(true)

                            Text(state.title)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(state.progressText)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .accessibilityHidden(true)

                    SwiftUI.ProgressView(value: min(max(state.progressFraction, 0), 1))
                        .tint(FormaTokens.Color.progress)
                        .accessibilityLabel(state.title)
                        .accessibilityValue(
                            FormaProductCopy.Journey.Milestones.Accessibility.progressPercent(
                                Int((state.progressFraction * 100).rounded())
                            )
                        )

                    Text(state.rewardCopy)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Near goal") {
    JourneyMilestonesSection(state: JourneyPreviewData.nearGoal.milestone)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
