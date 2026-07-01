//
//  PlanMissionControlHeroSection.swift
//  Fitness Coach
//
//  Forma — Goal-first Mission Control hero for the Plan dashboard.
//

import SwiftUI

struct PlanMissionControlHeroSection: View {
    let state: PlanMissionState

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(state.headlineValue)
                        .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    progressBlock

                    secondaryLines

                    Text(state.statusCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
        }
    }

    @ViewBuilder
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.progressRouteLabel)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if state.showsProgressBar {
                SwiftUI.ProgressView(value: progressBarFill)
                    .tint(FormaTokens.Color.progress)
                    .accessibilityLabel(FormaProductCopy.PlanMissionControl.heroSectionTitle)
                    .accessibilityValue(progressBarAccessibilityValue)

                if let progressCompleteLabel = state.progressCompleteLabel {
                    Text(progressCompleteLabel)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .accessibilityHidden(true)
                }
            } else if let progressCompleteLabel = state.progressCompleteLabel {
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
            if let expectedCompletionLabel = state.expectedCompletionLabel {
                Text(expectedCompletionLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }

            if let expectedWeeklyChangeLabel = state.expectedWeeklyChangeLabel {
                Text(expectedWeeklyChangeLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var progressBarFill: Double {
        let fill = max(state.progressBarFill, 0)
        if fill <= 0, state.showsProgressBar {
            return 0.02
        }
        return min(fill, 1)
    }

    private var progressBarAccessibilityValue: String {
        PlanMissionHeroCopyBuilder.progressBarAccessibilityValue(
            percent: state.progressPercent.map { $0 * 100 }
        )
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanMissionControlHeroSection(
        state: PlanMissionControlFixtures.loseDashboard.mission
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanMissionControlHeroSection(
        state: PlanMissionControlFixtures.loseDashboard.mission
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}

#Preview("Active user") {
    PlanMissionControlHeroSection(
        state: PlanMissionControlFixtures.activeUserDashboard.mission
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Maintain") {
    PlanMissionControlHeroSection(
        state: PlanMissionControlFixtures.maintainDashboard.mission
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
