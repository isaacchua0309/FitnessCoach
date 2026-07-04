//
//  WeeklyReviewDetailView.swift
//  Fitness Coach
//
//  Forma — Canonical weekly progress detail surface (“your week” ritual).
//

import SwiftUI

struct WeeklyReviewDetailView: View {
    enum Presentation: Equatable {
        case loading
        case empty
        case loaded(WeeklyProgressDetailState)
    }

    let presentation: Presentation
    var isLoading: Bool = false
    var onPrimaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onSecondaryCTA: ((WeeklyProgressCTA) -> Void)?

    init(detail: WeeklyProgressDetailState) {
        self.presentation = .loaded(detail)
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
                    switch presentation {
                    case .loading:
                        loadingContent
                    case .empty:
                        emptyContent
                    case .loaded(let detail):
                        loadedContent(detail)
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
        case .loaded(let detail):
            return detail.accessibilityLabel
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
        case .loaded(let detail):
            return detail.unified.dateRangeText
        }
    }

    private var headerTitle: String {
        switch presentation {
        case .loading:
            return FormaProductCopy.WeeklyReviewPresentation.loadingTitle
        case .empty:
            return FormaProductCopy.WeeklyReviewPresentation.emptyTitle
        case .loaded(let detail):
            return detail.unified.weekTitle
        }
    }

    @ViewBuilder
    private var loadingContent: some View {
        detailCard {
            narrativeBlock(FormaProductCopy.WeeklyReviewPresentation.loadingSubtitle)
            sectionDivider
            WeeklyReviewConfidenceFooter(
                confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceModerate,
                generatedAtLabel: "Updated Jul 3"
            )
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        detailCard {
            WeeklyReviewPhaseMessage(message: FormaProductCopy.WeeklyReviewPresentation.emptySummary)
            sectionDivider
            WeeklyReviewConfidenceFooter(
                confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceLow,
                generatedAtLabel: ""
            )
        }
    }

    @ViewBuilder
    private func loadedContent(_ detail: WeeklyProgressDetailState) -> some View {
        let unified = detail.unified

        if unified.isInsufficientData {
            insufficientDataCard(detail)
        }

        detailCard {
            WeeklyReviewDetailSection(title: "Overall verdict") {
                Text(detail.verdictTitle)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                narrativeBlock(unified.headline)
                narrativeBlock(unified.summary)
                narrativeBlock(detail.primaryInsight)
            }

            sectionDivider

            WeeklyReviewDetailSection(title: "Confidence") {
                WeeklyReviewConfidenceBadge(
                    label: unified.confidenceLabel,
                    isLimited: unified.isInsufficientData
                )
                narrativeBlock(unified.confidenceAccessibilityLabel)
            }

            if let maintenanceBlock = unified.maintenanceBlock {
                sectionDivider
                WeeklyReviewDetailSection(title: "Maintenance") {
                    WeeklyMaintenanceBlockView(state: maintenanceBlock)
                }
            }

            if let comparison = detail.staticTDEEComparison {
                sectionDivider
                WeeklyReviewDetailSection(title: "Formula comparison") {
                    narrativeBlock(comparison.comparisonCopy)
                }
            }

            if detail.consistency.hasContent {
                sectionDivider
                WeeklyReviewDetailSection(title: "Nutrition consistency") {
                    consistencyRows(detail.consistency)
                }
            }

            if let weightBlock = unified.weightTrendBlock {
                sectionDivider
                WeeklyReviewDetailSection(title: "Weight trend") {
                    WeeklyWeightTrendBlockView(
                        state: weightBlock,
                        spikeCopyStyle: .detail
                    )
                }
            }

            if let planBlock = unified.planRecommendationBlock {
                sectionDivider
                WeeklyReviewDetailSection(title: "Plan recommendation") {
                    WeeklyPlanRecommendationBlockView(state: planBlock)
                }
            }

            if !unified.habitRows.isEmpty {
                sectionDivider
                WeeklyReviewDetailSection(title: FormaProductCopy.Journey.WeeklyReview.sectionTitle) {
                    VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                        ForEach(Array(unified.habitRows.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 {
                                FormaPlanRowDivider()
                            }
                            WeeklyProgressHabitRowView(habit: habit)
                        }
                    }
                }
            }

            let winInsights = healthInsights(unified, kind: .win)
            if !winInsights.isEmpty {
                sectionDivider
                WeeklyReviewInsightList(
                    title: FormaProductCopy.WeeklyReviewPresentation.winsHeader,
                    items: winInsights
                )
            }

            let riskInsights = healthInsights(unified, kind: .risk)
            if !riskInsights.isEmpty {
                sectionDivider
                WeeklyReviewInsightList(
                    title: FormaProductCopy.WeeklyReviewPresentation.risksHeader,
                    items: riskInsights
                )
            }

            let supplementalInsights = healthInsights(unified, kind: .supplemental)
            if !supplementalInsights.isEmpty {
                sectionDivider
                WeeklyReviewDetailSection(title: "Health notes") {
                    ForEach(supplementalInsights) { insight in
                        narrativeBlock(insight.message)
                    }
                }
            }

            if let healthNotice = detail.healthKitLimitedNotice {
                sectionDivider
                WeeklyReviewPhaseMessage(message: healthNotice, tone: .caution)
            }

            if !unified.caveats.isEmpty {
                sectionDivider
                WeeklyReviewDetailSection(title: detail.uncertaintyTitle) {
                    ForEach(unified.caveats, id: \.self) { caveat in
                        narrativeBlock(caveat)
                    }
                }
            }

            if !detail.nextWeekFocus.isEmpty {
                sectionDivider
                WeeklyReviewFocusList(items: detail.nextWeekFocus)
            }

            sectionDivider

            WeeklyReviewConfidenceFooter(
                confidenceLabel: unified.confidenceLabel,
                missingDataNotice: nil,
                generatedAtLabel: detail.generatedAtLabel
            )

            ctaSection(unified)
        }
    }

    @ViewBuilder
    private func insufficientDataCard(_ detail: WeeklyProgressDetailState) -> some View {
        JourneyCard(elevation: .quiet) {
            VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
                Text(FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                narrativeBlock(detail.unified.headline)
                narrativeBlock(FormaProductCopy.WeeklyReviewPresentation.notEnoughDataRequirements)

                if !detail.unified.caveats.isEmpty {
                    ForEach(detail.unified.caveats, id: \.self) { caveat in
                        narrativeBlock(caveat)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ctaSection(_ unified: UnifiedWeeklyReviewState) -> some View {
        if let primaryCTA = unified.primaryCTA, let onPrimaryCTA {
            WeeklyProgressCTAButton(cta: primaryCTA, prominence: .primary) {
                onPrimaryCTA(primaryCTA)
            }
            .padding(.top, FormaTokens.Spacing.sm)
        }

        if let secondaryCTA = unified.secondaryCTA, let onSecondaryCTA {
            WeeklyProgressCTAButton(cta: secondaryCTA, prominence: .secondary) {
                onSecondaryCTA(secondaryCTA)
            }
        }
    }

    @ViewBuilder
    private func consistencyRows(_ consistency: WeeklyProgressConsistencySectionState) -> some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.listSpacing) {
            if let foodLoggedLabel = consistency.foodLoggedLabel {
                consistencyRow(title: "Food logging", value: foodLoggedLabel)
            }
            if let averageCaloriesLabel = consistency.averageCaloriesLabel {
                consistencyRow(title: "Average calories", value: averageCaloriesLabel)
            }
            if let proteinLabel = consistency.proteinLabel {
                consistencyRow(title: FormaProductCopy.WeeklyReviewPresentation.proteinTitle, value: proteinLabel)
            }
            if let waterLabel = consistency.waterLabel {
                consistencyRow(title: FormaProductCopy.WeeklyReviewPresentation.waterTitle, value: waterLabel)
            }
            if let calorieAdherenceLabel = consistency.calorieAdherenceLabel {
                consistencyRow(title: FormaProductCopy.WeeklyReviewPresentation.caloriesTitle, value: calorieAdherenceLabel)
            }
            if let trainingLabel = consistency.trainingLabel {
                consistencyRow(title: FormaProductCopy.Journey.WeeklyReview.trainingTitle, value: trainingLabel)
            }
        }
    }

    private func consistencyRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(JourneyTypography.metricLabel)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer(minLength: FormaTokens.Spacing.xs)
            Text(value)
                .font(JourneyTypography.cardSupporting.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func healthInsights(
        _ unified: UnifiedWeeklyReviewState,
        kind: WeeklyHealthInsightKind
    ) -> [WeeklyReviewInsightState] {
        unified.healthInsights
            .filter { $0.kind == kind }
            .map { insight in
                WeeklyReviewInsightState(
                    id: insight.id,
                    kind: kind == .risk ? .risk : .win,
                    message: insight.message,
                    accessibilityLabel: insight.accessibilityLabel
                )
            }
    }

    @ViewBuilder
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        JourneyCard(elevation: .standard) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                content()
            }
        }
    }

  private var sectionDivider: some View {
        FormaPlanRowDivider()
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
}

// MARK: - Section wrapper

private struct WeeklyReviewDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
            WeeklyReviewSectionHeader(title: title)
            content
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Strong week report") {
    NavigationStack {
        WeeklyReviewDetailView(detail: WeeklyReviewPresentationPreviewData.strongWeekProgressDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Insufficient data") {
    NavigationStack {
        WeeklyReviewDetailView(detail: WeeklyReviewPresentationPreviewData.sparseWeekProgressDetail)
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
        WeeklyReviewDetailView(detail: WeeklyReviewPresentationPreviewData.strongWeekProgressDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .preferredColorScheme(.dark)
}

#Preview("Large text") {
    NavigationStack {
        WeeklyReviewDetailView(detail: WeeklyReviewPresentationPreviewData.strongWeekProgressDetail)
            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
#endif
