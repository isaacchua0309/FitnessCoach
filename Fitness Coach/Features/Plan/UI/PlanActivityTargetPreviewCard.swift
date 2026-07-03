//
//  PlanActivityTargetPreviewCard.swift
//  Fitness Coach
//
//  Forma — Live target preview for Edit Plan activity step.
//

import SwiftUI

struct PlanActivityTargetPreviewCard: View {
    let state: PlanActivityTargetPreviewState

    private let projectionCopy = FormaProductCopy.PlanProjection.self
    private let activityCopy = FormaProductCopy.PlanEditActivity.self

    var body: some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(activityCopy.targetPreviewTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                if state.isComplete {
                    metricRow(
                        label: projectionCopy.maintenanceLabel,
                        value: state.maintenanceCalories
                    )
                    metricRow(
                        label: projectionCopy.targetCaloriesLabel,
                        value: state.targetCalories
                    )
                    metricRow(
                        label: projectionCopy.proteinLabel,
                        value: state.proteinTarget
                    )
                    metricRow(
                        label: activityCopy.trainingAssumptionLabel,
                        value: state.trainingAssumption
                    )
                } else {
                    Text(FormaProductCopy.PlanProjection.incompleteCalculation)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func metricRow(label: String, value: String?) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                Spacer(minLength: FormaTokens.Spacing.sm)
                Text(value)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

#if DEBUG
#Preview {
    PlanActivityTargetPreviewCard(
        state: PlanActivityTargetPreviewBuilder.build(
            projection: PlanProjectionBuilder.build(
                formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
                goalType: .loseFat
            ),
            formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
