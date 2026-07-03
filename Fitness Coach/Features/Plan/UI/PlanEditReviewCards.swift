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
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: isUpToDate ? "checkmark.circle.fill" : "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    isUpToDate
                        ? FormaPlanTokens.Color.planSuccess
                        : FormaPlanTokens.Color.planAccent
                )

            Text(headline)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(
                    isUpToDate
                        ? FormaPlanTokens.Color.planAccentSoft.opacity(0.55)
                        : FormaPlanTokens.Color.planSelectedCardBackground
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .stroke(
                    isUpToDate
                        ? FormaPlanTokens.Color.planSuccess.opacity(0.35)
                        : FormaPlanTokens.Color.planAccent.opacity(0.45),
                    lineWidth: 1
                )
        }
    }
}

struct PlanEditFinalPlanCard: View {
    let state: PlanEditFinalPlanSummaryState

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.finalPlanTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                metricRow(label: copy.goalLabel, value: state.goal)
                metricRow(label: copy.currentWeightLabel, value: state.currentWeight)
                metricRow(label: copy.targetWeightLabel, value: state.targetWeight)

                if let estimatedFinish = state.estimatedFinish {
                    metricRow(label: copy.estimatedFinishLabel, value: estimatedFinish)
                }

                if let calories = state.calories {
                    metricRow(
                        label: FormaProductCopy.PlanProjection.targetCaloriesLabel,
                        value: calories
                    )
                }
                if let protein = state.protein {
                    metricRow(label: FormaProductCopy.PlanProjection.proteinLabel, value: protein)
                }
                if let carbs = state.carbs {
                    metricRow(label: FormaProductCopy.PlanProjection.carbsLabel, value: carbs)
                }
                if let fat = state.fat {
                    metricRow(label: FormaProductCopy.PlanProjection.fatLabel, value: fat)
                }
                if let water = state.water {
                    metricRow(label: FormaProductCopy.PlanProjection.waterLabel, value: water)
                }

                metricRow(label: copy.difficultyAdherenceLabel, value: state.difficultyAdherence)
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
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

struct PlanEditInputChangesCard: View {
    let changes: [PlanEditFriendlyChange]

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanEditCard {
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
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planWarning)

            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planWarning)
                Text(warning.body)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaPlanTokens.Color.planWarningSoft)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .stroke(FormaPlanTokens.Color.planWarning.opacity(0.35), lineWidth: 1)
        }
    }
}

struct PlanEditTodayChangesCard: View {
    let changes: [PlanEditTodayTargetChange]
    let note: String

    private let copy = FormaProductCopy.PlanEditReview.self

    var body: some View {
        PlanEditCard {
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
