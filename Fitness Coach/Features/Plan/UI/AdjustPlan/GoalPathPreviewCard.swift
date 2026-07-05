//
//  GoalPathPreviewCard.swift
//  Fitness Coach
//
//  Forma — "Your path" outcome preview for the Adjust Plan goal step.
//

import SwiftUI

struct GoalPathPreviewCard: View {
    let state: PlanTransformationSummaryState

    @Environment(\.formaPlanColors) private var theme

    private let copy = FormaProductCopy.PlanEditTarget.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.transformationTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                PlanTimelinePreview(
                    model: PlanTimelinePreviewDisplayModel(
                        currentWeight: state.currentWeight,
                        targetWeight: state.targetWeight,
                        progressFraction: state.progressFraction
                    )
                )

                VStack(spacing: FormaTokens.Spacing.sm) {
                    PlanMetricRow(label: copy.currentLabel, value: state.currentWeight)
                    PlanMetricRow(label: copy.targetLabel, value: state.targetWeight)
                    PlanMetricRow(label: copy.totalChangeLabel, value: state.totalChange)

                    if let estimatedDuration = state.estimatedDuration {
                        PlanMetricRow(label: copy.estimatedDurationLabel, value: estimatedDuration)
                    }
                    if let estimatedFinish = state.estimatedFinish {
                        PlanMetricRow(label: copy.estimatedFinishLabel, value: estimatedFinish)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .formaThemeReactive()
    }

    private var accessibilitySummary: String {
        [
            copy.transformationTitle,
            "\(copy.currentLabel), \(state.currentWeight)",
            "\(copy.targetLabel), \(state.targetWeight)",
            "\(copy.totalChangeLabel), \(state.totalChange)",
            state.estimatedDuration.map { "\(copy.estimatedDurationLabel), \($0)" },
            state.estimatedFinish.map { "\(copy.estimatedFinishLabel), \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Goal Path Preview") {
    GoalPathPreviewCard(
        state: PlanTransformationSummaryState(
            currentWeight: "80 kg",
            targetWeight: "70 kg",
            totalChange: "10 kg between now and your goal.",
            estimatedDuration: "About 10 weeks",
            estimatedFinish: "March 2026",
            progressFraction: 0,
            isComplete: true
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
