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

// MARK: - Previews

#Preview("Activity assumptions") {
    PlanActivityAssumptionsSection(
        state: PlanMissionControlFixtures.loseDashboard.activityAssumptions,
        onAdjustActivity: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanActivityAssumptionsSection(
        state: PlanMissionControlFixtures.loseDashboard.activityAssumptions,
        onAdjustActivity: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}
