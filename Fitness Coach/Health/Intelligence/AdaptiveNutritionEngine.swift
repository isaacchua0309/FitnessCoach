//
//  AdaptiveNutritionEngine.swift
//  Fitness Coach
//
//  Forma — Training-aware calorie and macro adjustment recommendations.
//

import Foundation

protocol AdaptiveNutritionEngineing: Sendable {
    func nutritionAdjustment(
        for date: Date,
        activity: ActivitySummary,
        workout: WorkoutSummary?,
        trainingLoad: TrainingLoadSummary
    ) async -> AdaptiveNutritionSummary
}

struct AdaptiveNutritionEngine: AdaptiveNutritionEngineing {

    func nutritionAdjustment(
        for date: Date,
        activity: ActivitySummary,
        workout: WorkoutSummary?,
        trainingLoad: TrainingLoadSummary
    ) async -> AdaptiveNutritionSummary {
        // TODO: Apply training load and activity surplus/deficit rules to daily calorie targets.
        _ = (date, activity, workout, trainingLoad)
        return .none
    }
}
