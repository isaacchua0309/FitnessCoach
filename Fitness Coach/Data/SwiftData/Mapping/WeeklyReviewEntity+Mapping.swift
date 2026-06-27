//
//  WeeklyReviewEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension WeeklyReviewEntity {

    convenience init(model: WeeklyReview) {
        self.init(
            id: model.id,
            weekStartDate: model.weekStartDate,
            weekEndDate: model.weekEndDate,
            averageCalories: model.averageCalories,
            averageProtein: model.averageProtein,
            averageWaterMl: model.averageWaterMl,
            averageSteps: model.averageSteps,
            workoutCount: model.workoutCount,
            weightChangeKg: model.weightChangeKg,
            estimatedMaintenance: model.estimatedMaintenance,
            summaryText: model.summaryText,
            recommendationText: model.recommendationText,
            createdAt: model.createdAt
        )
    }

    func toModel() -> WeeklyReview {
        WeeklyReview(
            id: id,
            weekStartDate: weekStartDate,
            weekEndDate: weekEndDate,
            averageCalories: averageCalories,
            averageProtein: averageProtein,
            averageWaterMl: averageWaterMl,
            averageSteps: averageSteps,
            workoutCount: workoutCount,
            weightChangeKg: weightChangeKg,
            estimatedMaintenance: estimatedMaintenance,
            summaryText: summaryText,
            recommendationText: recommendationText,
            createdAt: createdAt
        )
    }
}
