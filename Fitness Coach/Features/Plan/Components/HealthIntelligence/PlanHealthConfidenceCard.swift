//
//  PlanHealthConfidenceCard.swift
//  Fitness Coach
//
//  Forma — Plan Health Intelligence confidence card.
//

import SwiftUI

struct PlanHealthConfidenceCard: View {
    let state: PlanHealthConfidenceCardState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.headerToCardSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            PlanHealthIntelligenceLoadingContainer(isLoading: isLoading || state.phase == .loading) {
                FormaPlanCard {
                    VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.contentSpacing) {
                        switch state.phase {
                        case .loading:
                            loadingContent
                        case .empty:
                            emptyContent
                        case .loaded:
                            loadedContent
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }

    @ViewBuilder
    private var loadingContent: some View {
        Text(state.headline)
            .font(PlanHealthIntelligenceTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)

        PlanHealthPhaseMessage(message: state.summary)
    }

    @ViewBuilder
    private var emptyContent: some View {
        Text(state.headline)
            .font(PlanHealthIntelligenceTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        PlanHealthPhaseMessage(message: state.summary, tone: .caution)
    }

    @ViewBuilder
    private var loadedContent: some View {
        Text(state.headline)
            .font(PlanHealthIntelligenceTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        PlanHealthPhaseMessage(message: state.summary)

        badgeRow

        if !state.reasons.isEmpty {
            reasonsBlock
        }

        if !state.disclaimerLine.isEmpty {
            Text(state.disclaimerLine)
                .font(PlanHealthIntelligenceTypography.cardCaption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, PlanHealthIntelligenceCardSupport.rowSpacing)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var badgeRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            if !state.confidenceLabel.isEmpty {
                PlanHealthConfidenceBadge(label: state.confidenceLabel)
            }

            if let scorePercent = state.scorePercent {
                PlanHealthScoreBadge(scorePercent: scorePercent)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, PlanHealthIntelligenceCardSupport.rowSpacing)
    }

    @ViewBuilder
    private var reasonsBlock: some View {
        VStack(alignment: .leading, spacing: PlanHealthIntelligenceCardSupport.rowSpacing) {
            Text(FormaProductCopy.PlanHealthIntelligencePresentation.confidenceReasonsHeading)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.top, PlanHealthIntelligenceCardSupport.rowSpacing)
                .accessibilityHidden(true)

            ForEach(Array(state.reasons.prefix(5)), id: \.self) { reason in
                PlanHealthReasonBulletRow(text: reason)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#Preview("Strong confidence") {
    PlanHealthConfidenceCard(state: PlanHealthIntelligencePresentationPreviewData.strongFit.confidenceCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Limited confidence") {
    PlanHealthConfidenceCard(state: PlanHealthIntelligencePresentationPreviewData.sparseSignals.confidenceCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Disconnected") {
    PlanHealthConfidenceCard(state: PlanHealthIntelligencePresentationPreviewData.disconnected.confidenceCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    PlanHealthConfidenceCard(state: .loading, isLoading: true)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    PlanHealthConfidenceCard(state: PlanHealthIntelligencePresentationPreviewData.strongFit.confidenceCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .blossomPink)
}
