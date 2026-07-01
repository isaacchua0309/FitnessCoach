//
//  DailyReviewEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension DailyReviewEntity {

    convenience init(model: DailyReview) {
        self.init(
            id: model.id,
            dailyLogId: model.dailyLogId,
            summaryText: model.summaryText,
            caloriesSummary: model.caloriesSummary,
            proteinSummary: model.proteinSummary,
            hydrationSummary: model.hydrationSummary,
            workoutSummary: model.workoutSummary,
            weightSummary: model.weightSummary,
            tomorrowRecommendation: model.tomorrowRecommendation,
            createdAt: model.createdAt
        )
    }

    func toModel() -> DailyReview {
        DailyReview(
            id: id,
            dailyLogId: dailyLogId,
            summaryText: summaryText,
            caloriesSummary: caloriesSummary,
            proteinSummary: proteinSummary,
            hydrationSummary: hydrationSummary,
            workoutSummary: workoutSummary,
            weightSummary: weightSummary,
            tomorrowRecommendation: tomorrowRecommendation,
            createdAt: createdAt
        )
    }
}
