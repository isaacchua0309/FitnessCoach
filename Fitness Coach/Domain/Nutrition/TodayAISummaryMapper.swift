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
            isOverCalorieTarget: nutrition.isOverCalories,
            proteinTarget: nutrition.targets.protein,
            proteinConsumed: nutrition.totals.protein,
            proteinRemaining: nutrition.remaining.protein,
            hasMetProteinTarget: nutrition.hasMetProteinTarget,
            carbsTarget: nutrition.targets.carbs,
            carbsConsumed: nutrition.totals.carbs,
            carbsRemaining: nutrition.remaining.carbs,
            fatTarget: nutrition.targets.fat,
            fatConsumed: nutrition.totals.fat,
            fatRemaining: nutrition.remaining.fat,
            waterTargetMl: nutrition.water.targetMl,
            waterConsumedMl: nutrition.water.consumedMl,
            waterRemainingMl: nutrition.water.remainingMl,
            hasMetWaterTarget: nutrition.hasMetWaterTarget,
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
            isOverCalorieTarget: reviewSummary.isOverCalorieTarget,
            proteinTarget: reviewSummary.proteinTarget,
            proteinConsumed: reviewSummary.proteinConsumed,
            proteinRemaining: reviewSummary.proteinRemaining,
            hasMetProteinTarget: reviewSummary.hasMetProteinTarget,
            carbsTarget: reviewSummary.carbsTarget,
            carbsConsumed: reviewSummary.carbsConsumed,
            carbsRemaining: reviewSummary.carbsRemaining,
            fatTarget: reviewSummary.fatTarget,
            fatConsumed: reviewSummary.fatConsumed,
            fatRemaining: reviewSummary.fatRemaining,
            waterTargetMl: reviewSummary.waterTargetMl,
            waterConsumedMl: reviewSummary.waterConsumedMl,
            waterRemainingMl: reviewSummary.waterRemainingMl,
            hasMetWaterTarget: reviewSummary.hasMetWaterTarget,
            weightKg: reviewSummary.weightKg,
            steps: reviewSummary.steps,
            workoutCaloriesBurned: reviewSummary.workoutCaloriesBurned,
            workoutsToday: reviewSummary.workoutCount,
            recentMeals: []
        )
    }

    static func dailyReviewAIInput(
        from summary: TodayAISummary,
        date: Date
    ) -> DailyReviewAIInput {
        DailyReviewAIInput(
            date: date,
            calorieTarget: summary.calorieTarget,
            caloriesConsumed: summary.caloriesConsumed,
            caloriesRemaining: summary.caloriesRemaining,
            isOverCalorieTarget: summary.isOverCalorieTarget,
            proteinTarget: summary.proteinTarget,
            proteinConsumed: summary.proteinConsumed,
            proteinRemaining: summary.proteinRemaining,
            hasMetProteinTarget: summary.hasMetProteinTarget,
            carbsTarget: summary.carbsTarget,
            carbsConsumed: summary.carbsConsumed,
            carbsRemaining: summary.carbsRemaining,
            fatTarget: summary.fatTarget,
            fatConsumed: summary.fatConsumed,
            fatRemaining: summary.fatRemaining,
            waterTargetMl: summary.waterTargetMl,
            waterConsumedMl: summary.waterConsumedMl,
            waterRemainingMl: summary.waterRemainingMl,
            hasMetWaterTarget: summary.hasMetWaterTarget,
            weightKg: summary.weightKg,
            latestWeightKg: summary.weightKg,
            steps: summary.steps,
            workoutCount: summary.workoutsToday,
            workoutCaloriesBurned: summary.workoutCaloriesBurned,
            foodEntryCount: summary.recentMeals.count,
            lowConfidenceFoodCount: 0,
            topProteinFoodNames: summary.recentMeals,
            deterministicNotes: []
        )
    }
}
