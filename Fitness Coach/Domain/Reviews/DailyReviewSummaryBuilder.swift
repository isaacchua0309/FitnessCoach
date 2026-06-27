//
//  DailyReviewSummaryBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds deterministic DailyReviewSummary values.
//
//  The builder is pure: no persistence, no AI, no service calls, and no UI.
//

import Foundation

struct DailyReviewSummaryBuilder {

    static func build(
        dailyLog: DailyLog,
        foodEntries: [FoodEntry],
        waterEntries: [WaterEntry],
        weightEntry: WeightEntry?,
        latestWeightEntry: WeightEntry?,
        workouts: [WorkoutEntry]
    ) -> DailyReviewSummary {
        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let workoutCalories = workouts.reduce(0) { $0 + ($1.estimatedCaloriesBurned ?? 0) }
        let lowConfidenceFoodCount = foodEntries.filter { $0.confidence == .low }.count
        let topProteinFoodNames = foodEntries
            .filter { $0.protein > 0 }
            .sorted { $0.protein > $1.protein }
            .prefix(3)
            .map(\.name)

        let summary = DailyReviewSummary(
            date: dailyLog.date,
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
            weightKg: dailyLog.weightKg ?? weightEntry?.weightKg,
            latestWeightKg: latestWeightEntry?.weightKg,
            steps: dailyLog.steps,
            workoutCount: workouts.count,
            workoutCaloriesBurned: max(dailyLog.workoutCaloriesBurned, workoutCalories),
            hasWorkout: !workouts.isEmpty,
            foodEntryCount: foodEntries.count,
            topProteinFoodNames: Array(topProteinFoodNames),
            lowConfidenceFoodCount: lowConfidenceFoodCount,
            deterministicNotes: []
        )

        return withNotes(summary, waterEntryCount: waterEntries.count)
    }

    private static func withNotes(
        _ summary: DailyReviewSummary,
        waterEntryCount: Int
    ) -> DailyReviewSummary {
        var updated = summary
        var notes: [String] = []

        if summary.isOverCalorieTarget {
            notes.append("Calories ended above target.")
        } else {
            notes.append("Calories stayed at or below target.")
        }

        if summary.hasMetProteinTarget {
            notes.append("Protein target reached.")
        } else {
            notes.append("Protein came up short today.")
        }

        if summary.hasMetWaterTarget {
            notes.append("Hydration goal reached.")
        } else {
            notes.append("Hydration goal not reached today.")
        }

        if summary.hasWorkout {
            notes.append("Workout was logged.")
        }

        if waterEntryCount == 0 {
            notes.append("No individual water entries were logged.")
        }

        if summary.lowConfidenceFoodCount > 0 {
            notes.append("\(summary.lowConfidenceFoodCount) low-confidence food estimate(s) were logged.")
        }

        updated.deterministicNotes = notes
        return updated
    }
}
