//
//  AdjustPlanSummaryCard.swift
//  Fitness Coach
//
//  Forma — Motivational hero summary for the Adjust Plan shell.
//

import SwiftUI

private enum AdjustPlanSummaryCardLayout {
    static let contentSpacing: CGFloat = FormaTokens.Spacing.xs
    static let metricSpacing: CGFloat = 2
    static let metricsRowSpacing: CGFloat = FormaTokens.Spacing.xs
}

struct AdjustPlanSummaryCard: View {
    let state: PlanEditHeroState

    @Environment(\.formaPlanColors) private var theme

    var body: some View {
        PlanProjectionCard(compact: true) {
            VStack(alignment: .leading, spacing: AdjustPlanSummaryCardLayout.contentSpacing) {
                Text(state.motivationalLine)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)

                HStack(alignment: .top, spacing: AdjustPlanSummaryCardLayout.metricsRowSpacing) {
                    heroMetric(label: state.goalLabel, value: state.goalValue)
                    heroMetric(label: state.currentWeightLabel, value: state.currentWeight)
                    heroMetric(label: state.targetWeightLabel, value: state.targetWeight)
                }

                if let totalChangeLine = state.totalChangeLine {
                    Text(totalChangeLine)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.interpolate)
                        .transition(.opacity)
                }

                if let estimatedFinishLine = state.estimatedFinishLine {
                    Text(estimatedFinishLine)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.interpolate)
                        .transition(.opacity)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
        .formaThemeReactive()
    }

    private func heroMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AdjustPlanSummaryCardLayout.metricSpacing) {
            Text(label)
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

    return AdjustPlanSummaryCard(state: PlanEditHeroStateBuilder.build(projection: projection))
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
