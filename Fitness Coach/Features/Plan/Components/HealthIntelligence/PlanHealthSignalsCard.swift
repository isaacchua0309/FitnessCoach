//
//  PlanHealthSignalsCard.swift
//  Fitness Coach
//
//  Forma — Health signals contributing to Plan Health Intelligence.
//

import SwiftUI

struct PlanHealthSignalsCard: View {
    let sectionTitle: String
    let signals: [PlanHealthSignalState]
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.headerToCardSpacing) {
            FormaSectionLabel(title: sectionTitle)

            PlanHealthIntelligenceLoadingContainer(isLoading: isLoading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.contentSpacing) {
                        Text(introMessage)
                            .font(PlanHealthIntelligenceTypography.cardBody)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .healthIntelligenceMultilineText()
                            .accessibilityHidden(true)

                        if signals.isEmpty {
                            PlanHealthPhaseMessage(
                                message: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySummaryEmpty,
                                tone: .caution
                            )
                        } else {
                            signalRows
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(signalsAccessibilityLabel)
        .accessibilityIdentifier("plan-hi-signals-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var signalRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                PlanHealthSignalStatusRow(signal: signal)
            }
        }
    }

    private var introMessage: String {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        let availableCount = signals.filter { $0.status == .available }.count
        switch availableCount {
        case 4...:
            return copy.dataQualitySummaryAvailable
        case 1...3:
            return copy.dataQualitySummaryLimited
        default:
            return copy.dataQualitySummaryEmpty
        }
    }

    private var signalsAccessibilityLabel: String {
        let labels = signals.map(\.accessibilityLabel)
        return "\(sectionTitle). \(labels.joined(separator: ". "))"
    }
}

// MARK: - Previews

#Preview("Strong signals") {
    PlanHealthSignalsCard(
        sectionTitle: PlanHealthIntelligencePresentationPreviewData.strongFit.dataQuality.sectionTitle,
        signals: PlanHealthIntelligencePresentationPreviewData.strongFit.dataQuality.signals
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial data") {
    PlanHealthSignalsCard(
        sectionTitle: PlanHealthIntelligencePresentationPreviewData.sparseSignals.dataQuality.sectionTitle,
        signals: PlanHealthIntelligencePresentationPreviewData.sparseSignals.dataQuality.signals
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Disconnected") {
    PlanHealthSignalsCard(
        sectionTitle: PlanHealthIntelligencePresentationPreviewData.disconnected.dataQuality.sectionTitle,
        signals: PlanHealthIntelligencePresentationPreviewData.disconnected.dataQuality.signals
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    PlanHealthSignalsCard(
        sectionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySectionTitle,
        signals: PlanHealthIntelligencePresentationPreviewData.strongFit.dataQuality.signals,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
