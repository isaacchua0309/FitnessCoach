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
            headerRow

            FitPilotPlanCard {
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            FormaSectionLabel(title: state.sectionTitle)

            Spacer(minLength: 8)

            if state.showsJourneyCTA, let onGoToJourney {
                Button(state.goToJourneyTitle, action: onGoToJourney)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                    .accessibilityLabel(state.goToJourneyTitle)
            }
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
    .preferredColorScheme(.dark)
}

#Preview("Weight milestone") {
    PlanNextMilestoneSection(
        state: PlanMissionControlFixtures.activeUserDashboard.nextMilestone,
        onGoToJourney: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
