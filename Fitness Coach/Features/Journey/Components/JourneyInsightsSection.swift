//
//  JourneyInsightsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyInsightsSection: View {
    let state: JourneyInsightState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .quiet) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if state.showsLearningState {
                        learningContent
                    } else {
                        ForEach(Array(state.insights.enumerated()), id: \.element.id) { index, insight in
                            if index > 0 {
                                FormaPlanRowDivider()
                            }
                            insightRow(insight)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var learningContent: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            if let title = state.learningTitle {
                Text(title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHidden(true)
            }

            if let detail = state.learningDetail {
                Text(detail)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightRow(_ insight: JourneyPersonalizedInsight) -> some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text(insight.title)
                .font(JourneyTypography.cardHeadline)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHidden(true)

            Text(insight.detail)
                .font(JourneyTypography.cardSupporting)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Learning state") {
    JourneyInsightsSection(
        state: JourneyInsightState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Journey.PersonalizedInsights.sectionTitle,
            showsLearningState: true,
            learningTitle: FormaProductCopy.Journey.PersonalizedInsights.learningTitle,
            learningDetail: FormaProductCopy.Journey.PersonalizedInsights.learningDetail,
            insights: [],
            accessibilitySummary: "Personal insights"
        )
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Personal insights") {
    JourneyInsightsSection(state: JourneyPreviewData.strongMomentum.insight)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
