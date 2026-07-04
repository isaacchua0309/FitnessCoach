//
//  PlanEditWeeklyReviewContextCard.swift
//  Fitness Coach
//
//  Forma — Read-only weekly review context inside Plan edit wizard.
//

import SwiftUI

struct PlanEditWeeklyReviewContextCard: View {
    let state: PlanEditWeeklyReviewContext

    private let copy = FormaProductCopy.PlanEditWeeklyReview.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                headerRow

                Text(state.message)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                maintenanceRows

                metricRow(
                    label: copy.currentTargetLabel,
                    value: PlanFormatter.kcal(state.currentCalorieTargetKcal)
                )

                if let delta = state.suggestedCalorieDelta,
                   let target = state.suggestedTargetKcal {
                    suggestedChangeRow(delta: delta, target: target)
                }

                if let confidence = state.confidenceLabel {
                    metricRow(label: copy.confidenceLabel, value: confidence)
                }

                if !state.caveats.isEmpty {
                    caveatsBlock
                }

                Text(state.safetyCopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(copy.contextCardTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(state.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var maintenanceRows: some View {
        if let formula = state.formulaMaintenanceKcal {
            metricRow(
                label: FormaProductCopy.PlanMissionControl.formulaMaintenanceLabel,
                value: PlanFormatter.kcal(formula)
            )
        }

        if let learned = state.learnedMaintenanceKcal {
            metricRow(
                label: FormaProductCopy.PlanMissionControl.learnedMaintenanceLabel,
                value: PlanFormatter.kcal(learned)
            )
        }
    }

    @ViewBuilder
    private var caveatsBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(copy.caveatsTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)

            ForEach(Array(state.caveats.enumerated()), id: \.offset) { _, caveat in
                Text(caveat)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(value)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
        }
    }

    private func suggestedChangeRow(delta: Int, target: Int) -> some View {
        let sign = delta > 0 ? "+" : ""
        return VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(copy.suggestedChangeLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                Text("\(sign)\(delta) kcal")
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)

                Text("→ \(PlanFormatter.kcal(target)) target")
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
            }
        }
    }
}

#if DEBUG
#Preview {
    let dashboard = PlanMissionControlFixtures.activeUserDashboard
    let context = PlanEditWeeklyReviewContextBuilder.build(from: dashboard)

    PlanEditWeeklyReviewContextCard(state: context)
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
