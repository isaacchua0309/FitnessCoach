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
        if state.isComplete {
            PlanMacroSummaryCard(model: summaryModel)
                .accessibilityElement(children: .combine)
        } else {
            PlanProjectionCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(activityCopy.targetPreviewTitle)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                    Text(FormaProductCopy.PlanProjection.incompleteCalculation)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var summaryModel: PlanMacroSummaryCardDisplayModel {
        var rows: [PlanMetricRowDisplayModel] = []

        if let maintenanceCalories = state.maintenanceCalories {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "maintenance",
                    label: projectionCopy.maintenanceLabel,
                    value: maintenanceCalories
                )
            )
        }
        if let targetCalories = state.targetCalories {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "target",
                    label: projectionCopy.targetCaloriesLabel,
                    value: targetCalories
                )
            )
        }
        if let proteinTarget = state.proteinTarget {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "protein",
                    label: projectionCopy.proteinLabel,
                    value: proteinTarget
                )
            )
        }
        if !state.trainingAssumption.isEmpty {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "training",
                    label: activityCopy.trainingAssumptionLabel,
                    value: state.trainingAssumption
                )
            )
        }

        return PlanMacroSummaryCardDisplayModel(
            title: activityCopy.targetPreviewTitle,
            rows: rows
        )
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
