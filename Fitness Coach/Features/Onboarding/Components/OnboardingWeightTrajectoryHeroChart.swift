//
//  OnboardingWeightTrajectoryHeroChart.swift
//  Fitness Coach
//
//  Forma — Large illustrative weight trajectory chart for intro proof.
//

import Charts
import SwiftUI

struct OnboardingWeightTrajectoryHeroChart: View {
    let model: OnboardingWeightTrajectoryComparisonModel
    var revealProgress: CGFloat = 1

    @ScaledMetric(relativeTo: .body) private var axisLabelSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var formaLineWidth: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var traditionalLineWidth: CGFloat = 3

    private enum Series: String, CaseIterable {
        case forma = "Forma"
        case traditional = "Traditional diet"
    }

    private struct ChartPoint: Identifiable {
        let id: String
        let weekIndex: Int
        let weightKg: Double
        let series: Series
    }

    private var chartPoints: [ChartPoint] {
        let formaPoints = model.formaSeries.enumerated().map { index, point in
            ChartPoint(id: point.id, weekIndex: index, weightKg: point.weightKg, series: .forma)
        }
        let traditionalPoints = model.traditionalSeries.enumerated().map { index, point in
            ChartPoint(id: point.id, weekIndex: index, weightKg: point.weightKg, series: .traditional)
        }
        return formaPoints + traditionalPoints
    }

    private var weekLabels: [String] {
        model.formaSeries.map(\.weekLabel)
    }

    private var yAxisDomain: ClosedRange<Double> {
        OnboardingWeightTrajectoryChartLayout.yAxisDomain(
            formaSeries: model.formaSeries,
            traditionalSeries: model.traditionalSeries
        )
    }

    var body: some View {
        Chart(chartPoints) { point in
            LineMark(
                x: .value("Week", point.weekIndex),
                y: .value("Weight", point.weightKg)
            )
            .foregroundStyle(by: .value("Series", point.series.rawValue))
            .interpolationMethod(.catmullRom)
            .lineStyle(lineStyle(for: point.series))
        }
        .chartForegroundStyleScale([
            Series.forma.rawValue: OnboardingTheme.chartPrimary,
            Series.traditional.rawValue: OnboardingTheme.chartSecondary
        ])
        .chartXScale(domain: 0...(max(model.formaSeries.count - 1, 0)))
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let index = value.as(Int.self), weekLabels.indices.contains(index) {
                    AxisValueLabel {
                        Text(weekLabels[index])
                            .font(.system(size: axisLabelSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(OnboardingTheme.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 6]))
                    .foregroundStyle(OnboardingTheme.border.opacity(0.35))
                AxisValueLabel()
                    .font(.system(size: axisLabelSize, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
        }
        .chartYAxisLabel {
            Text(FormaProductCopy.Onboarding.Flow.Proof.WeightMaintenance.yAxisLabel)
                .font(.system(size: axisLabelSize, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingTheme.tertiaryText)
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(OnboardingTheme.surfaceSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        }
        .mask(alignment: .leading) {
            Rectangle()
                .scaleEffect(x: max(0, min(revealProgress, 1)), y: 1, anchor: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.chartAccessibilityLabel)
        .accessibilityValue(model.takeaway)
    }

    private func lineStyle(for series: Series) -> StrokeStyle {
        switch series {
        case .forma:
            return StrokeStyle(lineWidth: formaLineWidth, lineCap: .round, lineJoin: .round)
        case .traditional:
            return StrokeStyle(
                lineWidth: traditionalLineWidth,
                lineCap: .round,
                lineJoin: .round,
                dash: [7, 5]
            )
        }
    }
}

// MARK: - Y-axis layout

enum OnboardingWeightTrajectoryChartLayout {

    /// Pads the combined series range so divergence is visible (avoids 0-based auto-scale).
    static func yAxisDomain(
        formaSeries: [OnboardingWeightTrendPoint],
        traditionalSeries: [OnboardingWeightTrendPoint],
        paddingRatio: Double = 0.12,
        minimumPadding: Double = 2.5
    ) -> ClosedRange<Double> {
        let weights = (formaSeries + traditionalSeries).map(\.weightKg)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...100
        }

        guard maxWeight > minWeight else {
            let center = minWeight
            return (center - minimumPadding)...(center + minimumPadding)
        }

        let span = maxWeight - minWeight
        let padding = max(span * paddingRatio, minimumPadding)
        return (minWeight - padding)...(maxWeight + padding)
    }
}

#if DEBUG
#Preview("Trajectory Hero Chart") {
    OnboardingWeightTrajectoryHeroChart(
        model: .introProofDefault,
        revealProgress: 1
    )
    .frame(height: 320)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
