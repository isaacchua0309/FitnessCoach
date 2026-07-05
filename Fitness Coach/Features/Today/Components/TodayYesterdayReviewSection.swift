//
//  TodayYesterdayReviewSection.swift
//  Fitness Coach
//
//  Forma — Lightweight yesterday daily-review teaser for Today.
//

import SwiftUI

struct TodayYesterdayReviewSection: View {
    let state: TodayYesterdayReviewState
    let isGenerating: Bool
    let onViewReview: (DailyReview) -> Void
    let onGenerateReview: (Date) -> Void
    var onViewed: (() -> Void)?

    var body: some View {
        if state.isVisible {
            VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
                TodaySectionLabel(title: state.sectionTitle)

                FormaPlanCard {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                        ForEach(Array(state.previewLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                        }

                        FormaQuickActionChip(
                            title: state.actionTitle,
                            action: performAction,
                            accessibilityHint: state.actionHint
                        )
                        .disabled(isGenerating)
                        .opacity(isGenerating ? 0.6 : 1)
                        .overlay {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, FormaTokens.Spacing.xs)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(state.accessibilityLabel)
            .onAppear {
                onViewed?()
            }
        }
    }

    private func performAction() {
        switch state.cta {
        case .viewReview:
            guard let review = state.review else { return }
            onViewReview(review)
        case .generateReview:
            onGenerateReview(state.reviewDate)
        }
    }
}

#Preview("Existing review") {
    TodayYesterdayReviewSection(
        state: TodayYesterdayReviewState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.YesterdayReview.sectionTitle,
            previewLines: [
                "Solid protein day with room to tighten calories.",
                "Calories: 1,720 / 1,800 kcal. You have 80 kcal remaining."
            ],
            actionTitle: FormaProductCopy.Today.YesterdayReview.viewAction,
            actionHint: FormaProductCopy.Today.YesterdayReview.viewHint,
            cta: .viewReview,
            reviewDate: Date(),
            review: DailyReview(
                id: UUID(),
                dailyLogId: UUID(),
                summaryText: "Solid protein day with room to tighten calories.",
                caloriesSummary: "Calories: 1,720 / 1,800 kcal. You have 80 kcal remaining.",
                proteinSummary: "Protein: 165 / 170g. You are 5g short of target.",
                hydrationSummary: "Water: 2,800 / 3,500ml. You have 700ml remaining.",
                workoutSummary: nil,
                weightSummary: nil,
                tomorrowRecommendation: "Prioritize lean protein earlier tomorrow.",
                createdAt: Date()
            ),
            analyticsFoodEntryCount: 3,
            accessibilityLabel: "Yesterday's review"
        ),
        isGenerating: false,
        onViewReview: { _ in },
        onGenerateReview: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
