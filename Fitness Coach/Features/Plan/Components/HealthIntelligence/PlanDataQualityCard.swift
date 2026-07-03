//
//  PlanDataQualityCard.swift
//  Fitness Coach
//
//  Forma — Data quality summary for Plan Health Intelligence.
//

import SwiftUI

struct PlanDataQualityCard: View {
    let state: PlanHealthDataQualityState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.headerToCardSpacing) {
            FormaSectionLabel(title: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityCardSectionTitle)

            PlanHealthIntelligenceLoadingContainer(isLoading: isLoading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.contentSpacing) {
                        PlanHealthDataQualityBadge(
                            level: state.qualityLevel,
                            label: state.qualityLabel
                        )

                        PlanHealthPhaseMessage(
                            message: state.explanation,
                            tone: state.qualityLevel == .limited ? .caution : .neutral
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }
}

// MARK: - Previews

#Preview("Strong quality") {
    PlanDataQualityCard(state: PlanHealthIntelligencePresentationPreviewData.strongFit.dataQuality)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Limited quality") {
    PlanDataQualityCard(state: PlanHealthIntelligencePresentationPreviewData.sparseSignals.dataQuality)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Disconnected") {
    PlanDataQualityCard(state: PlanHealthIntelligencePresentationPreviewData.disconnected.dataQuality)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Partial data") {
    PlanDataQualityCard(state: PlanHealthIntelligencePresentationPreviewData.partialData.dataQuality)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    PlanDataQualityCard(
        state: PlanHealthIntelligencePresentationPreviewData.strongFit.dataQuality,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
