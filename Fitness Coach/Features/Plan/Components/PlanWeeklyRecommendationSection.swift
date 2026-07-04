//
//  PlanWeeklyRecommendationSection.swift
//  Fitness Coach
//
//  Forma — Learned maintenance and safe weekly plan recommendation.
//

import SwiftUI

struct PlanWeeklyRecommendationSection: View {
    let state: PlanWeeklyRecommendationState
    var onReviewPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    maintenanceRows
                    recommendationBlock
                    safetyCopy
                    reviewPlanButton
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    @ViewBuilder
    private var maintenanceRows: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            maintenanceRow(
                label: state.formulaMaintenanceLabel,
                value: kcalLabel(for: state.formulaMaintenanceKcal)
            )

            if state.showsLearnedEstimate, let learned = state.learnedMaintenanceKcal {
                maintenanceRow(
                    label: state.learnedMaintenanceLabel,
                    value: kcalLabel(for: learned)
                )
            } else {
                Text(state.learnedMaintenanceUnavailableCopy)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var recommendationBlock: some View {
        if state.showsRecommendation,
           let title = state.recommendationTitle,
           let message = state.recommendationMessage {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        .accessibilityHidden(true)

                    Spacer(minLength: FormaTokens.Spacing.xs)

                    if let confidenceLabel = state.confidenceLabel {
                        Text(confidenceLabel)
                            .font(FormaTokens.Typography.caption2.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .accessibilityHidden(true)
                    }
                }

                Text(message)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                if let delta = state.suggestedCalorieDelta,
                   let target = state.suggestedTargetKcal {
                    recommendationDeltaRow(delta: delta, target: target)
                }
            }
            .padding(.top, FormaTokens.Spacing.xs)
        }
    }

    @ViewBuilder
    private var safetyCopy: some View {
        Text(state.safetyCopy)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, FormaTokens.Spacing.xs)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var reviewPlanButton: some View {
        if state.showsReviewPlanCTA {
            Button(action: onReviewPlan) {
                Text(state.reviewPlanButtonTitle)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .tint(FormaPlanTokens.Color.planAccentButton)
            .padding(.top, FormaTokens.Spacing.xs)
            .accessibilityLabel(state.reviewPlanButtonTitle)
            .accessibilityHint(FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint)
        }
    }

    private func maintenanceRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func recommendationDeltaRow(delta: Int, target: Int) -> some View {
        let sign = delta > 0 ? "+" : ""
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text("\(sign)\(delta) kcal")
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planAccent)

            Text("→ \(target) kcal target")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .accessibilityHidden(true)
    }

    private func kcalLabel(for kcal: Int?) -> String {
        guard let kcal, kcal > 0 else {
            return FormaProductCopy.PlanMissionControl.targetUnavailable
        }
        return PlanFormatter.kcal(kcal)
    }
}

#Preview("Insufficient data") {
    PlanWeeklyRecommendationSection(
        state: PlanMissionControlFixtures.loseDashboard.weeklyRecommendation,
        onReviewPlan: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Active user") {
    PlanWeeklyRecommendationSection(
        state: PlanMissionControlFixtures.activeUserDashboard.weeklyRecommendation,
        onReviewPlan: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
