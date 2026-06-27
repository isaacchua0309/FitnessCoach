//
//  TodayAISummaryMapper.swift
//  Fitness Coach
//
//  Maps DailyNutritionSummary and review summaries into TodayAISummary for AI context.
//

import Foundation

enum TodayAISummaryMapper {

    static func from(
        dailyLog: DailyLog,
        workoutsToday: Int = 0,
        recentMeals: [String] = []
    ) -> TodayAISummary {
        from(
            nutrition: DailyNutritionSummaryBuilder.build(from: dailyLog),
            dailyLog: dailyLog,
            workoutsToday: workoutsToday,
            recentMeals: recentMeals
        )
    }

    static func from(
        nutrition: DailyNutritionSummary,
        dailyLog: DailyLog,
        workoutsToday: Int = 0,
        recentMeals: [String] = []
    ) -> TodayAISummary {
        TodayAISummary(
            calorieTarget: nutrition.targets.calories,
            caloriesConsumed: nutrition.totals.calories,
            caloriesRemaining: nutrition.remaining.calories,
            proteinTarget: nutrition.targets.protein,
            proteinConsumed: nutrition.totals.protein,
            proteinRemaining: nutrition.remaining.protein,
            carbsTarget: nutrition.targets.carbs,
            carbsConsumed: nutrition.totals.carbs,
            carbsRemaining: nutrition.remaining.carbs,
            fatTarget: nutrition.targets.fat,
            fatConsumed: nutrition.totals.fat,
            fatRemaining: nutrition.remaining.fat,
            waterTargetMl: nutrition.water.targetMl,
            waterConsumedMl: nutrition.water.consumedMl,
            waterRemainingMl: nutrition.water.remainingMl,
            weightKg: dailyLog.weightKg,
            steps: dailyLog.steps,
            workoutCaloriesBurned: dailyLog.workoutCaloriesBurned,
            workoutsToday: workoutsToday,
            recentMeals: recentMeals
        )
    }

    static func from(reviewSummary: DailyReviewSummary) -> TodayAISummary {
        TodayAISummary(
            calorieTarget: reviewSummary.calorieTarget,
            caloriesConsumed: reviewSummary.caloriesConsumed,
            caloriesRemaining: reviewSummary.caloriesRemaining,
            proteinTarget: reviewSummary.proteinTarget,
            proteinConsumed: reviewSummary.proteinConsumed,
            proteinRemaining: reviewSummary.proteinRemaining,
            carbsTarget: reviewSummary.carbsTarget,
            carbsConsumed: reviewSummary.carbsConsumed,
            carbsRemaining: reviewSummary.carbsRemaining,
            fatTarget: reviewSummary.fatTarget,
            fatConsumed: reviewSummary.fatConsumed,
            fatRemaining: reviewSummary.fatRemaining,
            waterTargetMl: reviewSummary.waterTargetMl,
            waterConsumedMl: reviewSummary.waterConsumedMl,
            waterRemainingMl: reviewSummary.waterRemainingMl,
            weightKg: reviewSummary.weightKg,
            steps: reviewSummary.steps,
            workoutCaloriesBurned: reviewSummary.workoutCaloriesBurned,
            workoutsToday: reviewSummary.workoutCount,
            recentMeals: []
        )
    }
}
