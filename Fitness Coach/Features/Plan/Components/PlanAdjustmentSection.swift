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

            FormaPlanCard {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.lastUpdatedLabel)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .padding(.bottom, 4)
                            .accessibilityHidden(true)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(state.lastUpdateReasonHeading)
                                .font(FormaTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                            Text(state.lastUpdateReasonCopy)
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, FormaTokens.Spacing.sm)
                        .accessibilityHidden(true)

                        Text(state.currentHeading)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .padding(.bottom, FormaTokens.Spacing.xs)
                            .accessibilityHidden(true)

                        summaryRows
                            .accessibilityHidden(true)

                        Text(state.editSafetyCopy)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, FormaTokens.Spacing.xs)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(readOnlyAccessibilitySummary)

                    if state.canEditPlan {
                        Button(action: onAdjustPlan) {
                            Text(state.adjustPlanTitle)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FormaTokens.Color.ctaBackground)
                        .padding(.top, FormaTokens.Spacing.sm)
                        .accessibilityLabel(state.adjustPlanTitle)
                        .accessibilityHint(FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint)
                    }
                }
            }
        }
    }

    private var summaryRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.summaryRows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                FormaPlanDisplayRow(label: row.label, value: row.value)
            }
        }
    }

    private var readOnlyAccessibilitySummary: String {
        var parts = [
            state.sectionTitle,
            state.lastUpdatedLabel,
            "\(state.lastUpdateReasonHeading) \(state.lastUpdateReasonCopy)",
            state.currentHeading
        ]
        parts.append(contentsOf: state.summaryRows.map { "\($0.label), \($0.value)" })
        parts.append(state.editSafetyCopy)
        return parts.joined(separator: ". ")
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
    .formaThemePreview()
}

#Preview("New user") {
    PlanAdjustmentSection(
        state: PlanMissionControlFixtures.newUserDashboard.adjustment,
        onAdjustPlan: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
