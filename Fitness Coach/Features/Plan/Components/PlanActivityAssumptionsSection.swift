//
//  PlanActivityAssumptionsSection.swift
//  Fitness Coach
//
//  Forma — Activity assumptions card on the Plan dashboard.
//

import SwiftUI

struct PlanActivityAssumptionsSection: View {
    let state: PlanActivityAssumptionsState
    var onAdjustActivity: () -> Void
    var onConnectAppleHealth: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: 0) {
                    assumptionRows
                        .accessibilityHidden(true)

                    Text(state.assumptionsNote)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.sm)
                        .accessibilityHidden(true)

                    if state.showsAppleHealthStatus {
                        FitPilotPlanRowDivider()
                            .padding(.top, FormaTokens.Spacing.xs)

                        FitPilotPlanDisplayRow(
                            label: state.appleHealthFieldLabel,
                            value: state.appleHealthStatusLabel
                        )
                        .accessibilityHidden(true)
                    }

                    if state.showsConnectAppleHealthCTA, let onConnectAppleHealth {
                        Button(action: onConnectAppleHealth) {
                            Text(state.connectAppleHealthTitle)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityLabel(state.connectAppleHealthTitle)
                    }

                    Button(action: onAdjustActivity) {
                        Text(state.adjustActivityTitle)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, FormaTokens.Spacing.xs)
                    .accessibilityLabel(state.adjustActivityTitle)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var assumptionRows: some View {
        VStack(spacing: 0) {
            FitPilotPlanDisplayRow(
                label: state.activityFieldLabel,
                value: state.activityLevel
            )
            FitPilotPlanRowDivider()
            FitPilotPlanDisplayRow(
                label: state.estimatedStepsFieldLabel,
                value: state.estimatedStepsLabel
            )
            FitPilotPlanRowDivider()
            FitPilotPlanDisplayRow(
                label: state.trainingFieldLabel,
                value: state.trainingSessionsLabel
            )
        }
    }
}

// MARK: - Previews

#Preview("Disconnected") {
    PlanActivityAssumptionsSection(
        state: PlanMissionControlFixtures.loseDashboard.activityAssumptions,
        onAdjustActivity: {},
        onConnectAppleHealth: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Connected") {
    PlanActivityAssumptionsSection(
        state: PlanMissionControlFixtures.connectedDashboard.activityAssumptions,
        onAdjustActivity: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
