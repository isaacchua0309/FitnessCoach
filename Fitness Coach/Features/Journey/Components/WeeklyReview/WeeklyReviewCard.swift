//
//  WeeklyReviewCard.swift
//  Fitness Coach
//
//  Forma — Compact weekly review card for Journey surfaces.
//

import SwiftUI

struct WeeklyReviewCard: View {
    let state: WeeklyReviewCardState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            WeeklyReviewLoadingContainer(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .quiet) {
                    VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
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
        placeholderHeader
        Text(state.title)
            .font(WeeklyReviewTypography.cardTitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
        Text(state.summary)
            .font(WeeklyReviewTypography.body)
            .foregroundStyle(FormaTokens.Color.textSecondary)
    }

    @ViewBuilder
    private var emptyContent: some View {
        Text(state.title)
            .font(WeeklyReviewTypography.cardTitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        WeeklyReviewPhaseMessage(message: state.summary)
    }

    @ViewBuilder
    private var loadedContent: some View {
        if !state.dateRangeLabel.isEmpty {
            Text(state.dateRangeLabel)
                .font(WeeklyReviewTypography.eyebrow)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
        }

        Text(state.title)
            .font(WeeklyReviewTypography.cardTitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        Text(state.summary)
            .font(WeeklyReviewTypography.body)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)

        footerRow
    }

    @ViewBuilder
    private var footerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            if let headlineStatLabel = state.headlineStatLabel {
                WeeklyReviewHeadlineStatBadge(label: headlineStatLabel)
            }

            Spacer(minLength: 0)

            if !state.confidenceLabel.isEmpty {
                WeeklyReviewConfidenceBadge(
                    label: state.confidenceLabel,
                    isLimited: state.confidenceLabel == FormaProductCopy.WeeklyReviewPresentation.confidenceLow
                )
            }
        }
    }

    @ViewBuilder
    private var placeholderHeader: some View {
        Text("Jun 27 – Jul 3")
            .font(WeeklyReviewTypography.eyebrow)
            .foregroundStyle(FormaTokens.Color.textTertiary)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    WeeklyReviewCard(state: WeeklyReviewPresentationPreviewData.strongWeekCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Empty") {
    WeeklyReviewCard(state: WeeklyReviewPresentationPreviewData.emptyCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Loading") {
    WeeklyReviewCard(state: .loading, isLoading: true)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    WeeklyReviewCard(state: WeeklyReviewPresentationPreviewData.strongWeekCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(palette: .blossomPink)
}

#Preview("Dark mode") {
    WeeklyReviewCard(state: WeeklyReviewPresentationPreviewData.strongWeekCard)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
