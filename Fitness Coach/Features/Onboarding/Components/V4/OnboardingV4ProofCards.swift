//
//  OnboardingV4ProofCards.swift
//  Fitness Coach
//
//  Forma — Illustrative proof cards for v4 onboarding marketing screens.
//

import SwiftUI

struct OnboardingV4WeightTrendPoint: Equatable, Identifiable, Sendable {
    let id: String
    let weekLabel: String
    let weightKg: Double
}

struct OnboardingV4WeightTrajectoryComparisonModel: Equatable, Sendable {
    let caption: String
    let formaLabel: String
    let traditionalLabel: String
    let formaDescription: String
    let traditionalDescription: String
    let disclaimer: String
    let chartAccessibilityLabel: String
    let formaSeries: [OnboardingV4WeightTrendPoint]
    let traditionalSeries: [OnboardingV4WeightTrendPoint]

    static var introProofDefault: Self {
        let copy = FormaProductCopy.Onboarding.V4.self
        let trajectory = copy.Proof.TrajectoryComparison.self
        return OnboardingV4WeightTrajectoryComparisonModel(
            caption: copy.IntroProof.caption,
            formaLabel: trajectory.formaLabel,
            traditionalLabel: trajectory.traditionalLabel,
            formaDescription: trajectory.formaDescription,
            traditionalDescription: trajectory.traditionalDescription,
            disclaimer: trajectory.disclaimer,
            chartAccessibilityLabel: trajectory.chartAccessibilityLabel,
            formaSeries: [
                .init(id: "forma-w1", weekLabel: "W1", weightKg: 100),
                .init(id: "forma-w3", weekLabel: "W3", weightKg: 96),
                .init(id: "forma-w6", weekLabel: "W6", weightKg: 93),
                .init(id: "forma-w9", weekLabel: "W9", weightKg: 91.5),
                .init(id: "forma-w12", weekLabel: "W12", weightKg: 91)
            ],
            traditionalSeries: [
                .init(id: "traditional-w1", weekLabel: "W1", weightKg: 100),
                .init(id: "traditional-w3", weekLabel: "W3", weightKg: 94),
                .init(id: "traditional-w6", weekLabel: "W6", weightKg: 91),
                .init(id: "traditional-w9", weekLabel: "W9", weightKg: 94),
                .init(id: "traditional-w12", weekLabel: "W12", weightKg: 97)
            ]
        )
    }
}

struct OnboardingV4WeightMaintenanceProofModel: Equatable, Sendable {
    let title: String
    let subtitle: String
    let caption: String
    let yAxisLabel: String
    let points: [OnboardingV4WeightTrendPoint]

    static var introDefault: Self {
        let copy = FormaProductCopy.Onboarding.V4.Proof.WeightMaintenance.self
        return OnboardingV4WeightMaintenanceProofModel(
            title: copy.title,
            subtitle: copy.subtitle,
            caption: copy.caption,
            yAxisLabel: copy.yAxisLabel,
            points: [
                .init(id: "w1", weekLabel: "W1", weightKg: 72.4),
                .init(id: "w4", weekLabel: "W4", weightKg: 71.8),
                .init(id: "w8", weekLabel: "W8", weightKg: 71.2),
                .init(id: "w12", weekLabel: "W12", weightKg: 71.0)
            ]
        )
    }
}

struct OnboardingV4ComparisonBarProofModel: Equatable, Sendable {
    let title: String
    let subtitle: String
    let metricLabel: String
    let formaLabel: String
    let typicalLabel: String
    let formaValueLabel: String
    let typicalValueLabel: String
    let formaFill: Double
    let typicalFill: Double

    static var introDefault: Self {
        let copy = FormaProductCopy.Onboarding.V4.Proof.Comparison.self
        return OnboardingV4ComparisonBarProofModel(
            title: copy.title,
            subtitle: copy.subtitle,
            metricLabel: copy.metricLabel,
            formaLabel: copy.formaLabel,
            typicalLabel: copy.typicalLabel,
            formaValueLabel: copy.formaValueLabel,
            typicalValueLabel: copy.typicalValueLabel,
            formaFill: 0.82,
            typicalFill: 0.38
        )
    }
}

struct OnboardingV4FormaProofComparisonModel: Equatable, Sendable {
    let withoutFormaLabel: String
    let withFormaLabel: String
    let withoutFormaValue: String
    let withFormaValue: String
    let withoutFormaFill: Double
    let withFormaFill: Double
    let disclaimer: String
    let chartAccessibilityLabel: String

    static var `default`: Self {
        let copy = FormaProductCopy.Onboarding.V4.Proof.WeightLossComparison.self
        return OnboardingV4FormaProofComparisonModel(
            withoutFormaLabel: copy.withoutFormaLabel,
            withFormaLabel: copy.withFormaLabel,
            withoutFormaValue: copy.withoutFormaValue,
            withFormaValue: copy.withFormaValue,
            withoutFormaFill: copy.withoutFormaBarFill,
            withFormaFill: copy.withFormaBarFill,
            disclaimer: copy.disclaimer,
            chartAccessibilityLabel: copy.chartAccessibilityLabel
        )
    }
}

struct OnboardingV4WeightMaintenanceProofCard: View {
    let model: OnboardingV4WeightMaintenanceProofModel

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(model.title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.subtitle)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingV4ProofLineChart(
                points: model.points,
                strokeColor: OnboardingTheme.accent,
                showsPointMarkers: true
            )
            .frame(height: 132)
            .accessibilityLabel(model.caption)

            Text(model.caption)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(proofCardBackground)
        .accessibilityElement(children: .contain)
    }
}

struct OnboardingV4WeightTrajectoryComparisonProofCard: View {
    let model: OnboardingV4WeightTrajectoryComparisonModel

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            OnboardingV4ProofDualLineChart(
                primarySeries: model.formaSeries,
                secondarySeries: model.traditionalSeries,
                primaryColor: OnboardingTheme.accent,
                secondaryColor: OnboardingTheme.secondaryText.opacity(0.85)
            )
            .frame(height: 140)
            .accessibilityLabel(model.chartAccessibilityLabel)

            legendRow(
                color: OnboardingTheme.accent,
                title: model.formaLabel,
                subtitle: model.formaDescription
            )

            legendRow(
                color: OnboardingTheme.secondaryText.opacity(0.85),
                title: model.traditionalLabel,
                subtitle: model.traditionalDescription
            )

            Text(model.disclaimer)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.caption)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(proofCardBackground)
        .accessibilityElement(children: .contain)
    }

    private func legendRow(color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
                .padding(.top, 7)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                Text(subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

private struct OnboardingV4ProofComparisonBarRow: View {
    let label: String
    let valueLabel: String
    let fill: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                Spacer(minLength: 0)
                Text(valueLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FormaTokens.Color.surfaceElevated)
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(8, proxy.size.width * fill))
                }
            }
            .frame(height: 10)
            .accessibilityLabel("\(label), \(valueLabel)")
        }
    }
}

struct OnboardingV4FormaProofComparisonCard: View {
    let model: OnboardingV4FormaProofComparisonModel

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            OnboardingV4ProofComparisonBarRow(
                label: model.withoutFormaLabel,
                valueLabel: model.withoutFormaValue,
                fill: model.withoutFormaFill,
                tint: OnboardingTheme.secondaryText
            )

            OnboardingV4ProofComparisonBarRow(
                label: model.withFormaLabel,
                valueLabel: model.withFormaValue,
                fill: model.withFormaFill,
                tint: OnboardingTheme.accent
            )

            Text(model.disclaimer)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(proofCardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.chartAccessibilityLabel)
    }
}

struct OnboardingV4ComparisonBarProofCard: View {
    let model: OnboardingV4ComparisonBarProofModel

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(model.title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            Text(model.subtitle)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.metricLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .padding(.top, FormaTokens.Spacing.xs)

            comparisonRow(
                label: model.formaLabel,
                valueLabel: model.formaValueLabel,
                fill: model.formaFill,
                tint: OnboardingTheme.accent
            )

            comparisonRow(
                label: model.typicalLabel,
                valueLabel: model.typicalValueLabel,
                fill: model.typicalFill,
                tint: OnboardingTheme.secondaryText
            )
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(proofCardBackground)
        .accessibilityElement(children: .contain)
    }

    private func comparisonRow(
        label: String,
        valueLabel: String,
        fill: Double,
        tint: Color
    ) -> some View {
        OnboardingV4ProofComparisonBarRow(
            label: label,
            valueLabel: valueLabel,
            fill: fill,
            tint: tint
        )
    }
}

// MARK: - Shared chart primitives

private struct OnboardingV4ProofLineChart: View {
    let points: [OnboardingV4WeightTrendPoint]
    let strokeColor: Color
    var showsPointMarkers: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let normalizedPoints = OnboardingV4ProofChartLayout.normalizedPoints(
                for: points,
                in: proxy.size
            )

            ZStack {
                OnboardingV4ProofChartLayout.baseline(in: proxy.size)
                    .stroke(OnboardingTheme.border.opacity(0.6), lineWidth: 1)

                linePath(for: normalizedPoints)
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                if showsPointMarkers {
                    ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(strokeColor)
                            .frame(width: 6, height: 6)
                            .position(point)
                            .accessibilityHidden(true)
                            .overlay(alignment: .bottom) {
                                if points.indices.contains(index) {
                                    Text(points[index].weekLabel)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundStyle(OnboardingTheme.tertiaryText)
                                        .offset(y: 16)
                                }
                            }
                    }
                }
            }
        }
    }

    private func linePath(for points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }
}

private struct OnboardingV4ProofDualLineChart: View {
    let primarySeries: [OnboardingV4WeightTrendPoint]
    let secondarySeries: [OnboardingV4WeightTrendPoint]
    let primaryColor: Color
    let secondaryColor: Color

    var body: some View {
        GeometryReader { proxy in
            let combinedPoints = primarySeries + secondarySeries
            let primaryNormalized = OnboardingV4ProofChartLayout.normalizedPoints(
                for: primarySeries,
                in: proxy.size,
                valueRange: OnboardingV4ProofChartLayout.valueRange(for: combinedPoints)
            )
            let secondaryNormalized = OnboardingV4ProofChartLayout.normalizedPoints(
                for: secondarySeries,
                in: proxy.size,
                valueRange: OnboardingV4ProofChartLayout.valueRange(for: combinedPoints)
            )

            ZStack {
                OnboardingV4ProofChartLayout.baseline(in: proxy.size)
                    .stroke(OnboardingTheme.border.opacity(0.6), lineWidth: 1)

                linePath(for: secondaryNormalized)
                    .stroke(
                        secondaryColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4])
                    )

                linePath(for: primaryNormalized)
                    .stroke(
                        primaryColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(Array(primarySeries.enumerated()), id: \.offset) { index, point in
                    if index == 0 || index == primarySeries.count - 1 {
                        Text(point.weekLabel)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(OnboardingTheme.tertiaryText)
                            .position(
                                x: primaryNormalized.indices.contains(index)
                                    ? primaryNormalized[index].x
                                    : proxy.size.width / 2,
                                y: proxy.size.height - 4
                            )
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func linePath(for points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }
}

private enum OnboardingV4ProofChartLayout {
    static func valueRange(for points: [OnboardingV4WeightTrendPoint]) -> ClosedRange<Double>? {
        guard let minValue = points.map(\.weightKg).min(),
              let maxValue = points.map(\.weightKg).max(),
              maxValue > minValue else {
            return nil
        }
        return minValue...maxValue
    }

    static func normalizedPoints(
        for points: [OnboardingV4WeightTrendPoint],
        in size: CGSize,
        valueRange: ClosedRange<Double>? = nil
    ) -> [CGPoint] {
        let resolvedRange = valueRange ?? Self.valueRange(for: points)
        guard let resolvedRange else { return [] }

        let minValue = resolvedRange.lowerBound
        let maxValue = resolvedRange.upperBound
        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 20
        let usableWidth = max(size.width - horizontalPadding * 2, 1)
        let usableHeight = max(size.height - verticalPadding * 2, 1)

        return points.enumerated().map { index, point in
            let xProgress = points.count <= 1
                ? 0.5
                : Double(index) / Double(points.count - 1)
            let yProgress = (point.weightKg - minValue) / (maxValue - minValue)
            return CGPoint(
                x: horizontalPadding + usableWidth * xProgress,
                y: size.height - verticalPadding - usableHeight * yProgress
            )
        }
    }

    static func baseline(in size: CGSize) -> Path {
        Path { path in
            let baselineY = size.height - 16
            path.move(to: CGPoint(x: 8, y: baselineY))
            path.addLine(to: CGPoint(x: size.width - 8, y: baselineY))
        }
    }
}

private var proofCardBackground: some View {
    RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
        .fill(FormaTokens.Color.surfaceSubtle)
        .overlay {
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
        }
}
