//
//  WeeklyPlanRecommendationBlockView.swift
//  Fitness Coach
//
//  Forma — Safe plan recommendation block for the Journey weekly progress hero.
//

import SwiftUI

struct WeeklyPlanRecommendationBlockView: View {
    let state: WeeklyPlanRecommendationBlockState

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.blockSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(state.title)
                    .font(WeeklyProgressCardSupport.blockTitleFont)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(state.confidenceLabel)
                    .font(FormaTokens.Typography.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            Text(state.message)
                .font(WeeklyProgressCardSupport.supportingFont)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let delta = state.suggestedCalorieDelta, let target = state.suggestedTargetKcal {
                recommendationDeltaRow(delta: delta, target: target)
            }

            if let safetyNote = state.safetyNotes.first {
                Text(safetyNote)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }

    @ViewBuilder
    private func recommendationDeltaRow(delta: Int, target: Int) -> some View {
        let sign = delta > 0 ? "+" : ""
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text("\(sign)\(delta) kcal")
                .font(WeeklyProgressCardSupport.metricFont)
                .foregroundStyle(FormaTokens.Theme.primary)

            Text("→ \(target) kcal target")
                .font(WeeklyProgressCardSupport.supportingFont)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .accessibilityLabel("Suggested change \(sign)\(delta) kilocalories to a \(target) kilocalorie target")
    }
}

#if DEBUG
#Preview("Plan recommendation") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    if let block = unified.planRecommendationBlock {
        WeeklyPlanRecommendationBlockView(state: block)
            .padding()
            .background(FormaTokens.Color.canvas)
            .formaThemePreview()
    }
}
#endif
