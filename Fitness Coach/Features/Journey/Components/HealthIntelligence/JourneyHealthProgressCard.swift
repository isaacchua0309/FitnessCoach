//
//  JourneyHealthProgressCard.swift
//  Fitness Coach
//
//  Forma — Weekly health progress summary for Journey Health Intelligence.
//

import SwiftUI

struct JourneyHealthProgressCard: View {
    let state: JourneyHealthProgressState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .standard) {
                    VStack(alignment: .leading, spacing: JourneyHealthIntelligenceCardSupport.cardContentSpacing) {
                        progressHeadline

                        switch state.phase {
                        case .loading:
                            loadingContent
                        case .empty:
                            emptyContent
                        case .error:
                            errorContent
                        case .loaded:
                            loadedContent
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("journey-hi-progress-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var progressHeadline: some View {
        Text(state.headline)
            .font(JourneyTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHidden(state.phase == .loading)
    }

    @ViewBuilder
    private var loadingContent: some View {
        ForEach(0..<3, id: \.self) { index in
            if index > 0 {
                FormaPlanRowDivider()
            }
            FormaMetricRow(label: "Metric", value: "—", style: .snapshot)
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if let emptyMessage = state.emptyMessage {
            JourneyHealthIntelligencePhaseMessage(message: emptyMessage)
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let errorMessage = state.errorMessage {
            JourneyHealthIntelligencePhaseMessage(message: errorMessage, tone: .caution)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if !state.detailLines.isEmpty {
            VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                ForEach(Array(state.detailLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                }
            }
        }

        if !state.metrics.isEmpty {
            if !state.detailLines.isEmpty {
                FormaPlanRowDivider()
            }

            ForEach(Array(state.metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                metricRow(metric)
            }
        }
    }

    private func metricRow(_ metric: JourneyHealthProgressMetricRow) -> some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            FormaMetricRow(
                label: metric.title,
                value: metric.value,
                style: .snapshot
            )

            if let detail = metric.detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.leading, 0)
            }
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    JourneyHealthProgressCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.progress
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Empty") {
    JourneyHealthProgressCard(
        state: JourneyHealthIntelligencePreviewData.unavailable.progress
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    JourneyHealthProgressCard(
        state: JourneyHealthIntelligencePreviewData.loading.progress,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Ocean Blue") {
    JourneyHealthProgressCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.progress
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .oceanBlue)
}
