//
//  PlanThisWeekSection.swift
//  Fitness Coach
//
//  Forma — Weekly plan progress card on the Plan dashboard.
//

import SwiftUI

struct PlanThisWeekSection: View {
    let state: PlanWeekState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FitPilotPlanCard {
                if state.showsEmptyState, let emptyStateCopy = state.emptyStateCopy {
                    Text(emptyStateCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                } else {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                        weekStatusBlock

                        metricLines
                            .padding(.top, FormaTokens.Spacing.xs)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
        }
    }

    private var weekStatusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.overallHeadline)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .accessibilityHidden(true)

            Text(state.overallStatusCopy)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private var metricLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            metricLine(state.caloriesLine)
            metricLine(state.proteinLine)
            metricLine(state.waterLine)
            metricLine(state.trainingLine)
            metricLine(state.weightLine)
        }
        .accessibilityHidden(true)
    }

    private func metricLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

#Preview("Empty week") {
    PlanThisWeekSection(state: PlanMissionControlFixtures.newUserDashboard.week)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Active week") {
    PlanThisWeekSection(state: PlanMissionControlFixtures.activeUserDashboard.week)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
