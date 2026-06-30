//
//  PlanNextMilestoneSection.swift
//  Fitness Coach
//
//  Forma — Next milestone card on the Plan dashboard.
//

import SwiftUI

struct PlanNextMilestoneSection: View {
    let state: PlanNextMilestoneState
    var onGoToJourney: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionHeader(
                title: state.sectionTitle,
                actionTitle: state.showsJourneyCTA ? state.goToJourneyTitle : nil,
                actionAccessibilityHint: FormaProductCopy.PlanMissionControl.goToJourneyAccessibilityHint,
                action: onGoToJourney
            )

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(state.headline)
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if let detailCopy = state.detailCopy, detailCopy != state.headline {
                        Text(detailCopy)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHidden(true)
                    }

                    if let expectedDateLabel = state.expectedDateLabel {
                        Text(expectedDateLabel)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
        }
    }
}

// MARK: - Previews

#Preview("Logging milestone") {
    PlanNextMilestoneSection(
        state: PlanMissionControlFixtures.newUserDashboard.nextMilestone,
        onGoToJourney: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Weight milestone") {
    PlanNextMilestoneSection(
        state: PlanMissionControlFixtures.activeUserDashboard.nextMilestone,
        onGoToJourney: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
