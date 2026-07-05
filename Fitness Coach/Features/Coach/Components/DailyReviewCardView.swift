//
//  DailyReviewCardView.swift
//  Fitness Coach
//
//  Forma — Theme-reactive daily review card for Coach chat.
//

import SwiftUI

struct DailyReviewCardView: View {

    let payload: DailyReviewPayload

    @State private var isDetailsExpanded = false
    @ScaledMetric(relativeTo: .caption) private var progressBarHeight: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var compactSpacing: CGFloat = 6

    private var showsDetailsDisclosure: Bool {
        hasDetailNote || !payload.missingSignals.isEmpty
    }

    private var hasDetailNote: Bool {
        guard let detailNote = payload.detailNote else { return false }
        return !detailNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            headerSection
            statusSection
            metricsSection
            bestNextMoveSection

            if let tomorrowFocus = payload.tomorrowFocus,
               !tomorrowFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tomorrowSection(tomorrowFocus)
            }

            if showsDetailsDisclosure {
                detailsDisclosure
            }
        }
        .padding(CoachDesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            FormaCardChrome.background(.bordered)
        }
        .accessibilityElement(children: .contain)
        .formaThemeReactive()
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text("Daily Review")
                .font(CoachDesignTokens.Typography.confirmationTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .accessibilityAddTraits(.isHeader)

            if let timezoneLabel = payload.timezoneLabel,
               !timezoneLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(timezoneLabel)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
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
        VStack(alignment: .leading, spacing: compactSpacing) {
            DailyReviewMetricRowView(
                metric: payload.snapshot.calories,
                progressBarHeight: progressBarHeight,
                isOverTarget: payload.snapshot.calories.remainingText == "Over target"
            )
            DailyReviewMetricRowView(
                metric: payload.snapshot.protein,
                progressBarHeight: progressBarHeight,
                isOverTarget: false
            )
            DailyReviewMetricRowView(
                metric: payload.snapshot.water,
                progressBarHeight: progressBarHeight,
                isOverTarget: false
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var bestNextMoveSection: some View {
        labeledSection(title: "Best Next Move") {
            Text(payload.bestNextMove)
                .font(CoachDesignTokens.Typography.messageBody)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tomorrowSection(_ tomorrowFocus: String) -> some View {
        labeledSection(title: "Tomorrow") {
            Text(tomorrowFocus)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detailsDisclosure: some View {
        DisclosureGroup(isExpanded: $isDetailsExpanded) {
            VStack(alignment: .leading, spacing: compactSpacing) {
                if hasDetailNote, let detailNote = payload.detailNote {
                    labeledSection(title: "Coach note") {
                        Text(detailNote)
                            .font(CoachDesignTokens.Typography.hint)
                            .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !payload.missingSignals.isEmpty {
                    missingDataSection
                }
            }
            .padding(.top, CoachDesignTokens.Spacing.xxs)
        } label: {
            Text("Show details")
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.primary)
        }
        .tint(CoachDesignTokens.Color.primary)
    }

    private var missingDataSection: some View {
        labeledSection(title: "Missing Data") {
            DailyReviewMissingSignalChipsView(signals: payload.missingSignals)
        }
    }

    @ViewBuilder
    private func labeledSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(title)
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)
                .accessibilityAddTraits(.isHeader)

            content()
        }
    }
}

// MARK: - Metric row

private struct DailyReviewMetricRowView: View {
    let metric: ProgressMetric
    let progressBarHeight: CGFloat
    let isOverTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: CoachDesignTokens.Spacing.xs) {
                Text(metric.label)
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)
                    .layoutPriority(1)

                Spacer(minLength: CoachDesignTokens.Spacing.xs)

                Text(metricValueText)
                    .font(CoachDesignTokens.Typography.confirmationValue)
                    .foregroundStyle(CoachDesignTokens.Color.confirmationValue)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.85)
                    .monospacedDigit()
            }

            DailyReviewMetricProgressBarView(
                progress: metric.progress,
                height: progressBarHeight,
                isOverTarget: isOverTarget
            )

            Text(metric.remainingText)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.label)
        .accessibilityValue(accessibilityValueText)
    }

    private var metricValueText: String {
        let current = formattedValue(metric.current, unit: metric.unit)
        let target = formattedValue(metric.target, unit: metric.unit)
        return "\(current) / \(target)"
    }

    private var accessibilityValueText: String {
        "\(metricValueText). \(metric.remainingText)"
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

// MARK: - Progress bar

private struct DailyReviewMetricProgressBarView: View {
    let progress: Double
    let height: CGFloat
    let isOverTarget: Bool

    private var clampedProgress: Double {
        ProgressMetric.clampedProgress(progress)
    }

    private var fillColor: Color {
        if isOverTarget {
            return FormaTokens.Color.destructive.opacity(0.85)
        }
        return FormaTokens.Color.progress.opacity(0.85)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(FormaTokens.Color.progressTrack)

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? 4 : 0))
            }
        }
        .frame(minHeight: height, maxHeight: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Missing data chips

private struct DailyReviewMissingSignalChipsView: View {
    let signals: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: CoachDesignTokens.Spacing.xs, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            ForEach(signals, id: \.self) { signal in
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Missing data: \(signals.joined(separator: ", "))")
    }
}

#if DEBUG
#Preview("Daily Review Card") {
    ScrollView {
        DailyReviewCardView(payload: DailyReviewCardPreviewFixtures.samplePayload)
            .padding()
    }
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
#endif
