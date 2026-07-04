//
//  WeeklyWeightTrendBlockView.swift
//  Fitness Coach
//
//  Forma — Weight trend and scale-noise block for the Journey weekly progress hero.
//

import SwiftUI

struct WeeklyWeightTrendBlockView: View {
    let state: WeeklyWeightTrendBlockState

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.blockSpacing) {
            Text(state.title)
                .font(WeeklyProgressCardSupport.blockTitleFont)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if state.isLimited {
                Text(FormaProductCopy.WeeklyReviewPresentation.weightUnavailable)
                    .font(WeeklyProgressCardSupport.supportingFont)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            } else {
                weightSummary
            }

            if let spikeWarning = state.spikeWarning, state.hasSuddenSpike {
                WeeklyReviewPhaseMessage(message: spikeWarning, tone: .caution)
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }

    @ViewBuilder
    private var weightSummary: some View {
        if let changeLabel = state.changeLabel ?? state.weeklyChangeLabel {
            Text(changeLabel)
                .font(WeeklyProgressCardSupport.metricFont)
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }

        if let starting = state.startingWeightLabel, let ending = state.endingWeightLabel {
            Text("\(starting) → \(ending)")
                .font(WeeklyProgressCardSupport.supportingFont)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
    }
}

#if DEBUG
#Preview("Weight trend with spike") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    if let block = unified.weightTrendBlock {
        WeeklyWeightTrendBlockView(state: block)
            .padding()
            .background(FormaTokens.Color.canvas)
            .formaThemePreview()
    }
}
#endif
