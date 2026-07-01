//
//  JourneyWeeklyReviewSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklyReviewSection: View {
    let review: JourneyWeeklyReviewState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.WeeklyReview.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(review.weekSummaryCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let headline = review.consistencyHeadline {
                        consistencyBlock(headline: headline, detail: review.consistencyDetail)
                    }

                    ForEach(Array(review.rows.enumerated()), id: \.element.id) { index, row in
                        if index == 0 {
                            FormaPlanRowDivider()
                        }
                        reviewRow(row)
                        if index < review.rows.count - 1 {
                            FormaPlanRowDivider()
                        }
                    }

                    if let weekOverWeekDetail = review.weekOverWeekDetail {
                        FormaPlanRowDivider()
                        Text(weekOverWeekDetail)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let cta = JourneyCTARouter.weeklyTrainingCTA(training: review.training),
                       let onCTA {
                        FormaPlanRowDivider()
                        JourneyCTAButton(cta: cta) {
                            onCTA(cta)
                        }
                    }
                }
            }
        }
    }

    private func reviewRow(_ row: JourneyWeeklyReviewRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(row.icon)
                .font(FormaTokens.Typography.sectionSubtitle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                    Text(row.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textPrimary)

                    Spacer(minLength: FormaTokens.Spacing.xs)

                    Text(row.value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let detail = row.detail {
                    Text(detail)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.value)")
    }

    private func consistencyBlock(headline: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text("🔥")
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .accessibilityHidden(true)
                Text(headline)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }

            if let detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }
}

// MARK: - Previews

#Preview("Full week") {
    JourneyWeeklyReviewSection(review: JourneyPreviewData.weeklyReviewFullWeek)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Partial week") {
    JourneyWeeklyReviewSection(review: JourneyPreviewData.weeklyReviewPartialWeek)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Apple Health locked") {
    JourneyWeeklyReviewSection(review: JourneyPreviewData.weeklyReviewTrainingLocked)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
