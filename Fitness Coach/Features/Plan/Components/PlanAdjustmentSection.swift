//
//  PlanAdjustmentSection.swift
//  Fitness Coach
//
//  Forma — Adjust Plan entry point on the Plan dashboard.
//

import SwiftUI

struct PlanAdjustmentSection: View {
    let state: PlanAdjustmentState
    var onAdjustPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.currentHeading)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .padding(.bottom, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)

                    summaryRows
                        .accessibilityHidden(true)

                    if state.canEditPlan {
                        Button(action: onAdjustPlan) {
                            Text(state.adjustPlanTitle)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, FormaTokens.Spacing.sm)
                        .accessibilityLabel(state.adjustPlanTitle)
                    }

                    Text(state.editSafetyCopy)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var summaryRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.summaryRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    FitPilotPlanRowDivider()
                }
                FitPilotPlanDisplayRow(label: row.label, value: row.value)
            }
        }
    }
}

// MARK: - Previews

#Preview("Lose plan") {
    PlanAdjustmentSection(
        state: PlanMissionControlFixtures.loseDashboard.adjustment,
        onAdjustPlan: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("New user") {
    PlanAdjustmentSection(
        state: PlanMissionControlFixtures.newUserDashboard.adjustment,
        onAdjustPlan: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
