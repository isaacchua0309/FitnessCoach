//
//  CoachPendingFoodTrustSummaryView.swift
//  Fitness Coach
//
//  Forma — Trust-aware summary content for pending food confirmation.
//

import SwiftUI

struct CoachPendingFoodTrustSummaryView: View {
    let presentation: CoachPendingFoodEstimatePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            Text(presentation.mealName)
                .font(CoachDesignTokens.Typography.messageBody.weight(.semibold))
                .foregroundStyle(CoachDesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            trustMetricLine(presentation.estimatedCaloriesLine)

            if let rangeLine = presentation.likelyRangeLine {
                trustMetricLine(rangeLine)
            }

            trustMetricLine(presentation.confidenceLine)

            if let mainUncertainty = presentation.mainUncertaintyLine {
                trustMetricLine(mainUncertainty)
            }

            if let lowWarning = presentation.lowConfidenceWarning {
                Text(lowWarning)
                    .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
                    .foregroundStyle(CoachDesignTokens.Color.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let sanityWarning = presentation.sanityWarning, !sanityWarning.isEmpty {
                Text(sanityWarning)
                    .font(CoachDesignTokens.Typography.confirmationMetric.weight(.semibold))
                    .foregroundStyle(CoachDesignTokens.Color.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !presentation.assumptionLines.isEmpty {
                assumptionsSection
            }

            if !presentation.componentLines.isEmpty {
                componentsSection
            }

            if let sourceLine = presentation.sourceLine {
                Text(sourceLine)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }

            editHintsSection
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var assumptionsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(FormaProductCopy.Coach.pendingAssumptionsTitle)
                .font(CoachDesignTokens.Typography.hintLabel.weight(.semibold))
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            ForEach(Array(presentation.assumptionLines.enumerated()), id: \.offset) { _, line in
                bulletLine(line)
            }

            if presentation.hiddenAssumptionCount > 0 {
                Text(String(
                    format: FormaProductCopy.Coach.pendingMoreAssumptions,
                    presentation.hiddenAssumptionCount
                ))
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
        }
    }

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(FormaProductCopy.Coach.pendingComponentsTitle)
                .font(CoachDesignTokens.Typography.hintLabel.weight(.semibold))
                .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)

            ForEach(Array(presentation.componentLines.enumerated()), id: \.offset) { _, line in
                bulletLine(line)
            }

            if presentation.hiddenComponentCount > 0 {
                Text(String(
                    format: FormaProductCopy.Coach.pendingMoreComponents,
                    presentation.hiddenComponentCount
                ))
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
        }
    }

    private var editHintsSection: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
            Text(presentation.editHintLine)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)

            if let correctionHint = presentation.correctionHintLine {
                Text(correctionHint)
                    .font(CoachDesignTokens.Typography.hint)
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trustMetricLine(_ text: String) -> some View {
        Text(text)
            .font(CoachDesignTokens.Typography.confirmationMetric)
            .foregroundStyle(CoachDesignTokens.Color.confirmationLabel)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.xs) {
            Text("•")
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            Text(text)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
