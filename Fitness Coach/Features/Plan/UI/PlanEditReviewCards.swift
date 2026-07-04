//
//  PlanEditReviewCards.swift
//  Fitness Coach
//
//  Forma — Review step cards for Edit Plan.
//

import SwiftUI

struct PlanEditReviewStatusBanner: View {
    let headline: String
    let isUpToDate: Bool

    var body: some View {
        PlanSuccessCard(
            model: PlanSuccessCardDisplayModel(
                headline: headline,
                variant: .statusBanner(isUpToDate: isUpToDate)
            )
        )
    }
}

struct PlanEditFinalPlanCard: View {
    let state: PlanEditFinalPlanSummaryState

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanMacroSummaryCard(model: summaryModel)
    }

    private var summaryModel: PlanMacroSummaryCardDisplayModel {
        var rows: [PlanMetricRowDisplayModel] = [
            PlanMetricRowDisplayModel(id: "goal", label: copy.goalLabel, value: state.goal),
            PlanMetricRowDisplayModel(id: "current", label: copy.currentWeightLabel, value: state.currentWeight),
            PlanMetricRowDisplayModel(id: "target", label: copy.targetWeightLabel, value: state.targetWeight)
        ]

        if let estimatedFinish = state.estimatedFinish {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "finish",
                    label: copy.estimatedFinishLabel,
                    value: estimatedFinish
                )
            )
        }
        if let calories = state.calories {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "calories",
                    label: FormaProductCopy.PlanProjection.targetCaloriesLabel,
                    value: calories
                )
            )
        }
        if let protein = state.protein {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "protein",
                    label: FormaProductCopy.PlanProjection.proteinLabel,
                    value: protein
                )
            )
        }
        if let carbs = state.carbs {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "carbs",
                    label: FormaProductCopy.PlanProjection.carbsLabel,
                    value: carbs
                )
            )
        }
        if let fat = state.fat {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "fat",
                    label: FormaProductCopy.PlanProjection.fatLabel,
                    value: fat
                )
            )
        }
        if let water = state.water {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "water",
                    label: FormaProductCopy.PlanProjection.waterLabel,
                    value: water
                )
            )
        }

        rows.append(
            PlanMetricRowDisplayModel(
                id: "difficulty",
                label: copy.difficultyAdherenceLabel,
                value: state.difficultyAdherence
            )
        )

        return PlanMacroSummaryCardDisplayModel(
            title: copy.finalPlanTitle,
            rows: rows
        )
    }
}

struct PlanEditInputChangesCard: View {
    let changes: [PlanEditFriendlyChange]

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.inputChangesTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(change.label)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                        Text(change.summary)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct PlanEditReviewWarningCard: View {
    let warning: PlanEditReviewWarning

    var body: some View {
        PlanWarningCard(
            model: PlanWarningCardDisplayModel(
                title: warning.title,
                body: warning.body
            )
        )
    }
}

struct PlanEditTodayChangesCard: View {
    let changes: [PlanEditTodayTargetChange]
    let note: String

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.todayChangesTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.label)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planMutedText)

                        if let previousValue = change.previousValue {
                            Text("\(previousValue) → \(change.value)")
                                .font(FormaTokens.Typography.body)
                                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        } else {
                            Text(change.value)
                                .font(FormaTokens.Typography.body)
                                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        }
                    }
                }

                Text(note)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
