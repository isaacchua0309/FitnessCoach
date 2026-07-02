//
//  JourneyDetailedAnalyticsSection.swift
//  Fitness Coach
//

import Charts
import SwiftUI

struct JourneyDetailedAnalyticsSection: View {
    let analytics: JourneyDetailedAnalyticsState
    let selectedRangeDays: Int
    let onSelectRange: (Int) -> Void
    var onAnalyticsExpanded: (() -> Void)?
    var onCTA: ((JourneyCTA) -> Void)?

    @State private var isExpanded: Bool

    init(
        analytics: JourneyDetailedAnalyticsState,
        selectedRangeDays: Int,
        onSelectRange: @escaping (Int) -> Void,
        onAnalyticsExpanded: (() -> Void)? = nil,
        onCTA: ((JourneyCTA) -> Void)? = nil
    ) {
        self.analytics = analytics
        self.selectedRangeDays = selectedRangeDays
        self.onSelectRange = onSelectRange
        self.onAnalyticsExpanded = onAnalyticsExpanded
        self.onCTA = onCTA
        _isExpanded = State(initialValue: !analytics.isCollapsedByDefault)
    }

    var body: some View {
        FormaPlanCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    Text(FormaProductCopy.Journey.analyticsBasedOnDays(analytics.nutritionSummary.loggedDays))
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)

                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                        Text(FormaProductCopy.Journey.DetailedAnalytics.rangeTitle)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                        JourneyRangeSelector(
                            selectedRangeDays: selectedRangeDays,
                            onSelect: onSelectRange
                        )
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(FormaProductCopy.Journey.DetailedAnalytics.rangeTitle)

                    if analytics.showsWeightChart {
                        analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.weightTrendTitle) {
                            JourneyWeightTrendChart(
                                chartPoints: analytics.weightChartPoints,
                                interpretation: analytics.weightTrendInterpretation
                            )
                        }
                    } else if let weightCTA = analytics.weightLogCTA, let onCTA {
                        analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.weightTrendTitle) {
                            Text(analytics.weightTrendInterpretation)
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            JourneyCTAButton(cta: weightCTA) {
                                onCTA(weightCTA)
                            }
                        }
                    }

                    analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.nutritionTitle) {
                        analyticsRow("Avg calories", JourneyFormatter.kcal(analytics.nutritionSummary.averageCalories))
                        analyticsRow("Avg protein", JourneyFormatter.grams(analytics.nutritionSummary.averageProtein))
                        analyticsRow("Avg carbs", JourneyFormatter.grams(analytics.nutritionSummary.averageCarbs))
                        analyticsRow("Avg fat", JourneyFormatter.grams(analytics.nutritionSummary.averageFat))
                        if let fiber = analytics.nutritionSummary.averageFiber {
                            analyticsRow("Avg fiber", JourneyFormatter.grams(fiber))
                        }
                    }

                    analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.waterTitle) {
                        analyticsRow("Avg water", JourneyFormatter.ml(analytics.waterSummary.averageWaterMl))
                        analyticsRow("Avg target", JourneyFormatter.ml(analytics.waterSummary.averageWaterTargetMl))
                    }

                    trainingAnalyticsBlock
                }
                .padding(.top, FormaTokens.Spacing.sm)
            } label: {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(FormaProductCopy.Journey.DetailedAnalytics.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)

                    Text(FormaProductCopy.Journey.DetailedAnalytics.subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(FormaTokens.Theme.primary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FormaProductCopy.Journey.DetailedAnalytics.title)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                onAnalyticsExpanded?()
            }
        }
    }

    @ViewBuilder
    private var trainingAnalyticsBlock: some View {
        switch analytics.trainingDisplay {
        case .hidden:
            EmptyView()
        case .connectedEmpty:
            analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.trainingTitle) {
                Text(FormaProductCopy.Journey.DetailedAnalytics.noWorkoutsThisWeek)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
                Text(FormaProductCopy.Journey.DetailedAnalytics.trainingSourceNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        case .metrics(let workout):
            analyticsBlock(title: FormaProductCopy.Journey.DetailedAnalytics.trainingTitle) {
                Text(FormaProductCopy.Journey.DetailedAnalytics.trainingSourceNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .padding(.bottom, FormaTokens.Spacing.xs)
                analyticsRow("Workouts", "\(workout.workoutCount)")
                if let days = workout.workoutDays {
                    analyticsRow("Workout days", "\(days)")
                }
                analyticsRow(
                    "Active calories",
                    JourneyFormatter.kcal(workout.totalEstimatedCaloriesBurned)
                )
                if let duration = workout.averageDurationMinutes {
                    analyticsRow("Avg duration", "\(duration) min")
                }
            }
        }
    }

    private func analyticsBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FormaSectionLabel(title: title)
            content()
        }
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer(minLength: FormaTokens.Spacing.xs)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - Weight chart (analytics only)

private struct JourneyWeightTrendChart: View {
    let chartPoints: [WeightChartPoint]
    let interpretation: String

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Chart {
                ForEach(chartPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weightKg)
                    )
                    .foregroundStyle(FormaTokens.Color.chartPrimary.opacity(0.8))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weightKg)
                    )
                    .foregroundStyle(
                        point.isSynthetic
                            ? FormaTokens.Color.chartSecondary
                            : FormaTokens.Color.chartPrimary
                    )
                    .symbolSize(point.isSynthetic ? 28 : 20)
                }
            }
            .chartYAxisLabel("kg")
            .chartXAxis(.hidden)
            .frame(minHeight: chartHeight)
            .accessibilityLabel(FormaProductCopy.Journey.DetailedAnalytics.weightTrendTitle)
            .accessibilityValue(interpretation)

            Text(interpretation)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Sparse — log weight CTA") {
    ScrollView {
        JourneyDetailedAnalyticsSection(
            analytics: JourneyPreviewData.sparseData.detailedAnalytics,
            selectedRangeDays: 28
        ) { _ in }
        .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Detailed analytics") {
    ScrollView {
        JourneyDetailedAnalyticsSection(
            analytics: JourneyPreviewData.state.detailedAnalytics,
            selectedRangeDays: 28
        ) { _ in }
        .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
