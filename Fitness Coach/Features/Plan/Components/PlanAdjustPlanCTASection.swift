//
//  PlanAdjustPlanCTASection.swift
//  Fitness Coach
//
//  Forma — Compact bottom Adjust Plan call-to-action.
//

import SwiftUI

struct PlanAdjustPlanCTASection: View {
    let state: AdjustPlanCTAState
    var onAdjustPlan: () -> Void

    var body: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(state.heading)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                Text(state.bodyCopy)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                Button(action: onAdjustPlan) {
                    Text(state.buttonTitle)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(FormaPlanTokens.Color.planAccentButton)
                .disabled(!state.isEnabled)
                .padding(.top, FormaTokens.Spacing.xs)
                .accessibilityLabel(state.buttonTitle)
                .accessibilityHint(state.accessibilityHint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#Preview {
    PlanAdjustPlanCTASection(
        state: PlanMissionControlFixtures.loseDashboard.adjustPlanCTA,
        onAdjustPlan: {}
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
