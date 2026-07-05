//
//  WeeklyWeightTrendBlockView.swift
//  Fitness Coach
//
//  Forma — Weight trend and scale-noise block for the Journey weekly progress hero.
//

import SwiftUI

struct WeeklyWeightTrendBlockView: View {
    enum SpikeCopyStyle: Equatable {
        case short
        case detail
    }

    let state: WeeklyWeightTrendBlockState
    var spikeCopyStyle: SpikeCopyStyle = .short

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

            if state.hasSuddenSpike {
                spikeEducationBlock
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var spikeEducationBlock: some View {
        if let title = state.spikeTitle {
            Text(title)
                .font(WeeklyProgressCardSupport.supportingFont.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }

        if let body = resolvedSpikeBody {
            WeeklyReviewPhaseMessage(message: body, tone: .caution)
        }
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

    private var resolvedSpikeBody: String? {
        switch spikeCopyStyle {
        case .short:
            return state.spikeShortBody
        case .detail:
            return state.spikeDetailBody ?? state.spikeShortBody
        }
    }

    private var accessibilityLabel: String {
        if state.hasSuddenSpike, let spikeAccessibilityLabel = state.spikeAccessibilityLabel {
            return spikeAccessibilityLabel
        }
        return state.accessibilityLabel
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
