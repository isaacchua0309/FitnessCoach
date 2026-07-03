//
//  PlanTransformationSummaryCard.swift
//  Fitness Coach
//
//  Forma — Outcome summary for Edit Plan target weight step.
//

import SwiftUI

struct PlanTransformationSummaryCard: View {
    let state: PlanTransformationSummaryState

    private let copy = FormaProductCopy.PlanEditTarget.self

    var body: some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.transformationTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                PlanTransformationProgressTrack(
                    currentWeight: state.currentWeight,
                    targetWeight: state.targetWeight,
                    progressFraction: state.progressFraction
                )

                metricsGrid
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var metricsGrid: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            metricRow(label: copy.currentLabel, value: state.currentWeight)
            metricRow(label: copy.targetLabel, value: state.targetWeight)
            metricRow(label: copy.totalChangeLabel, value: state.totalChange)

            if let estimatedDuration = state.estimatedDuration {
                metricRow(label: copy.estimatedDurationLabel, value: estimatedDuration)
            }
            if let estimatedFinish = state.estimatedFinish {
                metricRow(label: copy.estimatedFinishLabel, value: estimatedFinish)
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer(minLength: FormaTokens.Spacing.sm)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var accessibilitySummary: String {
        [
            copy.transformationTitle,
            "\(copy.currentLabel), \(state.currentWeight)",
            "\(copy.targetLabel), \(state.targetWeight)",
            "\(copy.totalChangeLabel), \(state.totalChange)",
            state.estimatedDuration.map { "\(copy.estimatedDurationLabel), \($0)" },
            state.estimatedFinish.map { "\(copy.estimatedFinishLabel), \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}

struct PlanTransformationProgressTrack: View {
    let currentWeight: String
    let targetWeight: String
    let progressFraction: Double

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let markerSize: CGFloat = 12
                let trackY = geometry.size.height / 2
                let startX = markerSize / 2
                let endX = width - markerSize / 2
                let fillWidth = max(0, (endX - startX) * progressFraction)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FormaPlanTokens.Color.planProgressTrack)
                        .frame(height: 6)
                        .position(x: width / 2, y: trackY)

                    if fillWidth > 0 {
                        Capsule()
                            .fill(FormaPlanTokens.Color.planProgressFill)
                            .frame(width: fillWidth, height: 6)
                            .position(x: startX + fillWidth / 2, y: trackY)
                    }

                    Circle()
                        .fill(FormaPlanTokens.Color.planAccent)
                        .frame(width: markerSize, height: markerSize)
                        .position(x: startX, y: trackY)

                    Circle()
                        .strokeBorder(FormaPlanTokens.Color.planAccent, lineWidth: 2)
                        .background(Circle().fill(FormaPlanTokens.Color.planSurface))
                        .frame(width: markerSize, height: markerSize)
                        .position(x: endX, y: trackY)
                }
            }
            .frame(height: 20)

            HStack {
                Text(currentWeight)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                Spacer()
                Text(targetWeight)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Transformation Summary") {
    PlanTransformationSummaryCard(
        state: PlanTransformationSummaryState(
            currentWeight: "80 kg",
            targetWeight: "70 kg",
            totalChange: "10 kg to your target.",
            estimatedDuration: "About 10 weeks",
            estimatedFinish: "March 2026",
            progressFraction: 0,
            isComplete: true
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
