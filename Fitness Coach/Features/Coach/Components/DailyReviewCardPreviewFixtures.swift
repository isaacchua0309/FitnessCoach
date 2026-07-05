//
//  DailyReviewCardPreviewFixtures.swift
//  Fitness Coach
//
//  Preview fixtures for DailyReviewCard.
//

import Foundation

#if DEBUG
enum DailyReviewCardPreviewFixtures {
    static let samplePayload = DailyReviewPayload(
        title: "Daily Review",
        timezoneLabel: "Jul 5, 2026 · GMT",
        generatedAt: Date(),
        snapshot: DailyReviewSnapshot(
            calories: ProgressMetric(
                label: "Calories",
                current: 1_620,
                target: 2_000,
                unit: "kcal",
                remainingText: "Under target",
                progress: 0.81
            ),
            protein: ProgressMetric(
                label: "Protein",
                current: 118,
                target: 140,
                unit: "g",
                remainingText: "Gap to close",
                progress: 0.84
            ),
            water: ProgressMetric(
                label: "Water",
                current: 1_800,
                target: 2_500,
                unit: "ml",
                remainingText: "Gap to close",
                progress: 0.72
            )
        ),
        statusSummary: "You are still within today's calorie target.",
        bestNextMove: "Add 22g protein at your next meal.",
        tomorrowFocus: "Drink 700ml more water today.",
        missingSignals: ["Steps", "HRV"],
        detailNote: "Solid protein pacing today."
    )
}
#endif
