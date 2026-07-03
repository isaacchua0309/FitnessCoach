//
//  PlanMissionControlHeroSection.swift
//  Fitness Coach
//
//  Forma — Goal-first hero for the Plan dashboard.
//

import SwiftUI

struct PlanMissionControlHeroSection: View {
    let strategy: PlanStrategyState
    let status: PlanStatusState

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: strategy.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(strategy.headline)
                        .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    progressBlock

                    secondaryLines

                    Text(status.message)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(statusToneColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    @ViewBuilder
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(strategy.progressRouteLabel)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if strategy.showsProgressBar {
                SwiftUI.ProgressView(value: progressBarFill)
                    .tint(FormaTokens.Color.progress)
                    .accessibilityLabel(FormaProductCopy.PlanMissionControl.heroSectionTitle)
                    .accessibilityValue(progressBarAccessibilityValue)

                if let progressCompleteLabel = strategy.progressCompleteLabel {
                    Text(progressCompleteLabel)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .accessibilityHidden(true)
                }
            } else if let progressCompleteLabel = strategy.progressCompleteLabel {
                Text(progressCompleteLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var secondaryLines: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let expectedCompletionLabel = strategy.expectedCompletionLabel {
                Text(expectedCompletionLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }

            if let expectedPaceLabel = strategy.expectedPaceLabel {
                Text(expectedPaceLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var progressBarFill: Double {
        let fill = max(strategy.progressBarFill, 0)
        if fill <= 0, strategy.showsProgressBar {
            return 0.02
        }
        return min(fill, 1)
    }

    private var progressBarAccessibilityValue: String {
        PlanMissionHeroCopyBuilder.progressBarAccessibilityValue(
            percent: strategy.showsProgressBar ? strategy.progressBarFill * 100 : nil
        )
    }

    private var statusToneColor: Color {
        switch status.tone {
        case .onTrack, .aheadOfSchedule, .newPlan:
            return FormaTokens.Color.textSecondary
        case .needsData:
            return FormaTokens.Color.textSecondary
        }
    }

    private var accessibilitySummary: String {
        [strategy.accessibilitySummary, status.message].joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy,
        status: PlanMissionControlFixtures.loseDashboard.status
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.loseDashboard.strategy,
        status: PlanMissionControlFixtures.loseDashboard.status
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}

#Preview("Active user") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.activeUserDashboard.strategy,
        status: PlanMissionControlFixtures.activeUserDashboard.status
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Maintain") {
    PlanMissionControlHeroSection(
        strategy: PlanMissionControlFixtures.maintainDashboard.strategy,
        status: PlanMissionControlFixtures.maintainDashboard.status
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
