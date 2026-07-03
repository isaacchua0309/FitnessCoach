//
//  PlanAssumptionsSection.swift
//  Fitness Coach
//
//  Forma — Collapsible Plan Assumptions card.
//

import SwiftUI

struct PlanAssumptionsSection: View {
    let state: PlanAssumptionsState
    var onAdjustActivity: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaPlanCard {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 {
                                FormaPlanRowDivider()
                            }
                            FormaPlanDisplayRow(label: row.label, value: row.value)
                                .accessibilityHidden(true)
                        }

                        Button(action: onAdjustActivity) {
                            Text(state.adjustActivityTitle)
                                .font(FormaTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(FormaPlanTokens.Color.planAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, FormaTokens.Spacing.sm)
                        .accessibilityLabel(state.adjustActivityTitle)
                        .accessibilityHint(FormaProductCopy.PlanMissionControl.updateActivityAccessibilityHint)
                    }
                    .padding(.top, FormaTokens.Spacing.xs)
                    .accessibilityHidden(true)
                } label: {
                    FormaSectionLabel(title: state.sectionTitle)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#Preview("Plan assumptions") {
    PlanAssumptionsSection(
        state: PlanMissionControlFixtures.loseDashboard.assumptions,
        onAdjustActivity: {}
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
