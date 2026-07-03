//
//  PlanAssumptionsSection.swift
//  Fitness Coach
//
//  Forma — Plan assumptions card: activity, steps, and training in one place.
//

import SwiftUI

struct PlanAssumptionsSection: View {
    let state: PlanAssumptionsState
    var onAdjustActivity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        FormaPlanDisplayRow(
                            label: state.activityFieldLabel,
                            value: state.activityLevel
                        )
                        .accessibilityHidden(true)

                        FormaPlanRowDivider()

                        FormaPlanDisplayRow(
                            label: state.estimatedStepsFieldLabel,
                            value: state.estimatedStepsLabel
                        )
                        .accessibilityHidden(true)

                        FormaPlanRowDivider()

                        FormaPlanDisplayRow(
                            label: state.trainingFieldLabel,
                            value: state.trainingSessionsLabel
                        )
                        .accessibilityHidden(true)

                        Text(state.assumptionsNote)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, FormaTokens.Spacing.sm)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(state.accessibilitySummary)

                    Button(action: onAdjustActivity) {
                        Text(state.adjustActivityTitle)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Theme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, FormaTokens.Spacing.sm)
                    .accessibilityLabel(state.adjustActivityTitle)
                    .accessibilityHint(FormaProductCopy.PlanMissionControl.updateActivityAccessibilityHint)
                }
            }
        }
    }
}

#Preview("Plan assumptions") {
    PlanAssumptionsSection(
        state: PlanMissionControlFixtures.loseDashboard.assumptions,
        onAdjustActivity: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
