//
//  WeeklyReviewConfidenceFooter.swift
//  Fitness Coach
//
//  Forma — Confidence and freshness footer for weekly review detail.
//

import SwiftUI

struct WeeklyReviewConfidenceFooter: View {
    let confidenceLabel: String
    var missingDataNotice: String?
    let generatedAtLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: WeeklyReviewCardSupport.contentSpacing) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                WeeklyReviewConfidenceBadge(
                    label: confidenceLabel,
                    isLimited: confidenceLabel == FormaProductCopy.WeeklyReviewPresentation.confidenceLow
                )

                Spacer(minLength: 0)

                if !generatedAtLabel.isEmpty {
                    Text(generatedAtLabel)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }

            if let missingDataNotice {
                WeeklyReviewPhaseMessage(message: missingDataNotice, tone: .caution)
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(footerAccessibilityLabel)
        .formaThemeReactive()
    }

    private var footerAccessibilityLabel: String {
        var parts = ["Confidence, \(confidenceLabel)"]
        if !generatedAtLabel.isEmpty {
            parts.append(generatedAtLabel)
        }
        if let missingDataNotice {
            parts.append(missingDataNotice)
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Full confidence") {
    WeeklyReviewConfidenceFooter(
        confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceModerate,
        generatedAtLabel: "Updated Jul 3"
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Limited with notice") {
    WeeklyReviewConfidenceFooter(
        confidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceLow,
        missingDataNotice: "Weight and recovery were limited this week, so parts of this review use partial data.",
        generatedAtLabel: "Updated Jul 3"
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}
