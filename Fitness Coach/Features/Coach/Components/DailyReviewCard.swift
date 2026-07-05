//
//  DailyReviewCard.swift
//  Fitness Coach
//
//  Forma — Structured daily review card for Coach chat.
//

import SwiftUI

struct DailyReviewCard: View {
    let payload: DailyReviewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            headerSection
            statusSection
            metricsSection

            if let detailNote = payload.detailNote, !detailNote.isEmpty {
                detailSection(detailNote)
            }

            bestNextMoveSection

            if let tomorrowFocus = payload.tomorrowFocus, !tomorrowFocus.isEmpty {
                tomorrowFocusSection(tomorrowFocus)
            }

            if !payload.missingSignals.isEmpty {
                missingSignalsSection
            }
        }
        .padding(CoachDesignTokens.Spacing.md)
        .background {
            FormaCardChrome.background(.bordered)
        }
        .accessibilityElement(children: .combine)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(payload.title)
                .font(CoachDesignTokens.Typography.confirmationTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)

            if let timezoneLabel = payload.timezoneLabel, !timezoneLabel.isEmpty {
                Text(timezoneLabel)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
        }
    }

    private var statusSection: some View {
        Text(payload.statusSummary)
            .font(CoachDesignTokens.Typography.messageBody)
            .foregroundStyle(CoachDesignTokens.Color.textLegal)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            metricRow(payload.snapshot.calories)
            metricRow(payload.snapshot.protein)
            metricRow(payload.snapshot.water)
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: ProgressMetric) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs + 2) {
            HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.xs) {
                Text(metric.label)
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

                Spacer(minLength: CoachDesignTokens.Spacing.xs)

                Text(metricValueText(metric))
                    .font(CoachDesignTokens.Typography.confirmationValue)
                    .foregroundStyle(CoachDesignTokens.Color.confirmationValue)
                    .monospacedDigit()
            }

            DailyReviewMetricProgressBar(progress: metric.progress)

            Text(metric.remainingText)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.label), \(metricValueText(metric)), \(metric.remainingText)")
    }

    private func detailSection(_ detailNote: String) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Coach note")
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            Text(detailNote)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bestNextMoveSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Best next move")
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            Text(payload.bestNextMove)
                .font(CoachDesignTokens.Typography.messageBody)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tomorrowFocusSection(_ tomorrowFocus: String) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Tomorrow focus")
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            Text(tomorrowFocus)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var missingSignalsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Missing signals")
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            HStack(spacing: CoachDesignTokens.Spacing.xs) {
                ForEach(payload.missingSignals, id: \.self) { signal in
                    Text(signal)
                        .font(CoachDesignTokens.Typography.confirmationMetric)
                        .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                        .padding(.horizontal, CoachDesignTokens.Spacing.xs)
                        .padding(.vertical, CoachDesignTokens.Spacing.xxs)
                        .background(
                            CoachDesignTokens.Color.border.opacity(0.25),
                            in: Capsule(style: .continuous)
                        )
                }
            }
        }
    }

    private func metricValueText(_ metric: ProgressMetric) -> String {
        let current = formattedValue(metric.current, unit: metric.unit)
        let target = formattedValue(metric.target, unit: metric.unit)
        return "\(current) / \(target)"
    }

    private func formattedValue(_ value: Double, unit: String) -> String {
        if unit == "g" {
            return "\(FoodEntryFormFormatter.formatMacro(value))\(unit)"
        }
        if value.rounded() == value {
            return "\(Int(value)) \(unit)"
        }
        return String(format: "%.1f %@", value, unit)
    }
}

private struct DailyReviewMetricProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(CoachDesignTokens.Color.border.opacity(0.35))

                Capsule(style: .continuous)
                    .fill(CoachDesignTokens.Color.primary.opacity(0.85))
                    .frame(width: max(geometry.size.width * progress, progress > 0 ? 4 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    DailyReviewCard(payload: DailyReviewCardPreviewFixtures.samplePayload)
        .padding()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}
#endif
