//
//  WeeklyReviewDetailView.swift
//  Fitness Coach
//
//  Forma — Coaching-style weekly review detail surface.
//

import SwiftUI

struct WeeklyReviewDetailView: View {
    enum Presentation: Equatable {
        case loading
        case empty
        case loaded(WeeklyReviewDetailState)
    }

    let presentation: Presentation
    var isLoading: Bool = false

    init(state: WeeklyReviewDetailState) {
        self.presentation = .loaded(state)
    }

    init(presentation: Presentation, isLoading: Bool = false) {
        self.presentation = presentation
        self.isLoading = isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
                reportHeader

                WeeklyReviewLoadingContainer(isLoading: showsLoadingRedaction) {
                    JourneyCard(elevation: .standard) {
                        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                            switch presentation {
                            case .loading:
                                loadingContent
                            case .empty:
                                emptyContent
                            case .loaded(let state):
                                loadedContent(state)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, JourneyLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .formaThemeReactive()
    }

    private var showsLoadingRedaction: Bool {
        isLoading || presentation == .loading
    }

    private var accessibilityLabel: String {
        switch presentation {
        case .loading:
            return FormaProductCopy.WeeklyReviewPresentation.loadingAccessibilityLabel
        case .empty:
            return FormaProductCopy.WeeklyReviewPresentation.emptyAccessibilityLabel
        case .loaded(let state):
            return state.accessibilityLabel
        }
    }

    @ViewBuilder
    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.listSpacing) {
            if !headerDateRangeLabel.isEmpty {
                Text(headerDateRangeLabel)
                    .font(WeeklyReviewTypography.eyebrow)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Text(headerTitle)
                .font(WeeklyReviewTypography.reportTitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var headerDateRangeLabel: String {
        switch presentation {
        case .loading:
            return "Jun 27 – Jul 3"
        case .empty:
            return ""
        case .loaded(let state):
            return state.dateRangeLabel
        }
    }

    private var headerTitle: String {
        switch presentation {
        case .loading:
            return FormaProductCopy.WeeklyReviewPresentation.loadingTitle
        case .empty:
            return FormaProductCopy.WeeklyReviewPresentation.emptyTitle
        case .loaded(let state):
            return state.title
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        narrativeBlock(FormaProductCopy.WeeklyReviewPresentation.loadingSubtitle)

        FormaPlanRowDivider()

        WeeklyReviewStatsGrid(state: placeholderStatsGrid)

        FormaPlanRowDivider()

        WeeklyReviewConfidenceFooter(
            confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceModerate,
            generatedAtLabel: "Updated Jul 3"
        )
    }

    @ViewBuilder
    private var emptyContent: some View {
        WeeklyReviewPhaseMessage(message: FormaProductCopy.WeeklyReviewPresentation.emptySummary)

        FormaPlanRowDivider()

        WeeklyReviewConfidenceFooter(
            confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceLow,
            generatedAtLabel: ""
        )
    }

    @ViewBuilder
    private func loadedContent(_ state: WeeklyReviewDetailState) -> some View {
        narrativeBlock(state.summary)

        FormaPlanRowDivider()

        WeeklyReviewStatsGrid(state: state.statsGrid)

        if !state.wins.isEmpty {
            FormaPlanRowDivider()
            WeeklyReviewInsightList(
                title: FormaProductCopy.WeeklyReviewPresentation.winsHeader,
                items: state.wins
            )
        }

        if !state.risks.isEmpty {
            FormaPlanRowDivider()
            WeeklyReviewInsightList(
                title: FormaProductCopy.WeeklyReviewPresentation.risksHeader,
                items: state.risks
            )
        }

        if !state.nextWeekFocus.isEmpty {
            FormaPlanRowDivider()
            WeeklyReviewFocusList(items: state.nextWeekFocus)
        }

        FormaPlanRowDivider()

        WeeklyReviewConfidenceFooter(
            confidenceLabel: state.confidenceLabel,
            missingDataNotice: state.missingDataNotice,
            generatedAtLabel: state.generatedAtLabel
        )
    }

    @ViewBuilder
    private func narrativeBlock(_ summary: String) -> some View {
        Text(summary)
            .font(JourneyTypography.cardDetail)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    private var placeholderStatsGrid: WeeklyReviewStatsGridState {
        WeeklyReviewStatsGridState(
            items: [
                WeeklyReviewStatItemState(
                    id: "workouts",
                    title: FormaProductCopy.WeeklyReviewPresentation.workoutsTitle,
                    value: "4 workouts",
                    detail: nil,
                    isLimited: false
                ),
                WeeklyReviewStatItemState(
                    id: "steps",
                    title: FormaProductCopy.WeeklyReviewPresentation.stepsTitle,
                    value: "8,200",
                    detail: nil,
                    isLimited: false
                ),
                WeeklyReviewStatItemState(
                    id: "protein",
                    title: FormaProductCopy.WeeklyReviewPresentation.proteinTitle,
                    value: "5 of 7 days",
                    detail: nil,
                    isLimited: false
                ),
                WeeklyReviewStatItemState(
                    id: "recovery",
                    title: FormaProductCopy.WeeklyReviewPresentation.recoveryTitle,
                    value: "Avg 68",
                    detail: nil,
                    isLimited: false
                )
            ],
            accessibilityLabel: FormaProductCopy.WeeklyReviewPresentation.statsSectionTitle
        )
    }
}

// MARK: - Previews

#Preview("Strong week report") {
    NavigationStack {
        WeeklyReviewDetailView(state: WeeklyReviewPresentationPreviewData.strongWeekDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Sparse week report") {
    NavigationStack {
        WeeklyReviewDetailView(state: WeeklyReviewPresentationPreviewData.sparseWeekDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}

#Preview("Loading") {
    NavigationStack {
        WeeklyReviewDetailView(presentation: .loading, isLoading: true)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Empty") {
    NavigationStack {
        WeeklyReviewDetailView(presentation: .empty)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Dark mode") {
    NavigationStack {
        WeeklyReviewDetailView(state: WeeklyReviewPresentationPreviewData.strongWeekDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack {
        WeeklyReviewDetailView(state: WeeklyReviewPresentationPreviewData.strongWeekDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
