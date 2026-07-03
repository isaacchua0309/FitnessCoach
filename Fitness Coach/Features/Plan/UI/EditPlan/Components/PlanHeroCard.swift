//
//  PlanHeroCard.swift
//  Fitness Coach
//
//  Forma — Motivational hero summary for Edit Plan shell.
//

import SwiftUI

struct PlanHeroCard: View {
    let state: PlanEditHeroState

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(state.motivationalLine)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                    heroMetric(label: state.goalLabel, value: state.goalValue)
                    heroMetric(label: state.currentWeightLabel, value: state.currentWeight)
                    heroMetric(label: state.targetWeightLabel, value: state.targetWeight)
                }

                if let totalChangeLine = state.totalChangeLine {
                    Text(totalChangeLine)
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let estimatedFinishLine = state.estimatedFinishLine {
                    Text(estimatedFinishLine)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private func heroMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

    return PlanHeroCard(state: PlanEditHeroStateBuilder.build(projection: projection))
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
