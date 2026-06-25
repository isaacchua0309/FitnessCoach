//
//  TodayDailyReviewCard.swift
//  Fitness Coach
//
//  FitPilot AI — Daily review summary card for Today.
//

import SwiftUI

struct TodayDailyReviewCard: View {
    let review: DailyReview?
    let isGenerating: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Review")
                .font(.headline)

            if let review {
                Text(review.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(review.caloriesSummary)
                    Text(review.proteinSummary)
                    Text(review.hydrationSummary)
                    if let workoutSummary = review.workoutSummary {
                        Text(workoutSummary)
                    }
                    if let weightSummary = review.weightSummary {
                        Text(weightSummary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(review.tomorrowRecommendation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Text("Generate a review of today's nutrition, hydration, and training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onGenerate()
                } label: {
                    if isGenerating {
                        HStack(spacing: 8) {
                            SwiftUI.ProgressView()
                            Text("Generating...")
                        }
                    } else {
                        Text("Generate Daily Review")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    TodayDailyReviewCard(
        review: nil,
        isGenerating: false,
        onGenerate: {}
    )
    .padding()
}
