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
                remainingText: "380 kcal remaining",
                progress: 0.81
            ),
            protein: ProgressMetric(
                label: "Protein",
                current: 118,
                target: 140,
                unit: "g",
                remainingText: "22g to go",
                progress: 0.84
            ),
            water: ProgressMetric(
                label: "Water",
                current: 1_800,
                target: 2_500,
                unit: "ml",
                remainingText: "700 ml remaining",
                progress: 0.72
            )
        ),
        statusSummary: "You logged 1,620 kcal with 380 kcal remaining.",
        bestNextMove: "Prioritize lean protein earlier tomorrow.",
        tomorrowFocus: "Workout: 1 session logged, estimated 320 kcal burned.",
        missingSignals: ["Steps aren't available from Apple Health right now."],
        detailNote: "Solid logging day. Protein was close to target and hydration trailed in the afternoon."
    )
}
#endif
