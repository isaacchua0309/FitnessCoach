//
//  PlanEditReviewStepView.swift
//  Fitness Coach
//
//  Forma — Review changes step for Edit Plan.
//

import SwiftUI

struct PlanEditReviewStepView: View {
    let summary: PlanEditFinalPlanSummaryState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            PlanEditReviewStatusBanner(
                headline: summary.headline,
                isUpToDate: summary.isUpToDate
            )

            if let warning = summary.warning {
                PlanEditReviewWarningCard(warning: warning)
            }

            PlanEditFinalPlanCard(state: summary)

            if !summary.inputChanges.isEmpty {
                PlanEditInputChangesCard(changes: summary.inputChanges)
            }

            if !summary.todayChanges.isEmpty {
                PlanEditTodayChangesCard(
                    changes: summary.todayChanges,
                    note: summary.todayNote
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Review — Changes") {
    let baseline = PlanMissionControlFixtures.loseProfile
    var formState = PlanFormState(profile: baseline)
    formState.goalWeightKgText = "70"
    let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
    let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)
    let summary = PlanEditFinalPlanSummaryBuilder.build(
        baseline: baseline,
        formState: formState,
        goalType: .loseFat,
        projection: projection,
        review: review
    )

    return ScrollView {
        PlanEditReviewStepView(summary: summary)
            .padding()
    }
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
