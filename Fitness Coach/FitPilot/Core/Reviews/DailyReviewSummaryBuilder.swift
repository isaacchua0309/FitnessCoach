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
        let targets = MacroCalculator.macroTargets(from: dailyLog.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: dailyLog.totals)
        let waterRemainingMl = WaterTargetCalculator.remainingMl(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl
        )
        let workoutCalories = workouts.reduce(0) { $0 + ($1.estimatedCaloriesBurned ?? 0) }
        let lowConfidenceFoodCount = foodEntries.filter { $0.confidence == .low }.count
        let topProteinFoodNames = foodEntries
            .filter { $0.protein > 0 }
            .sorted { $0.protein > $1.protein }
            .prefix(3)
            .map(\.name)

        let summary = DailyReviewSummary(
            date: dailyLog.date,
            calorieTarget: targets.calories,
            caloriesConsumed: dailyLog.totals.calories,
            caloriesRemaining: remaining.calories,
            isOverCalorieTarget: MacroCalculator.isOverCalories(
                totals: dailyLog.totals,
                targets: targets
            ),
            proteinTarget: targets.protein,
            proteinConsumed: dailyLog.totals.protein,
            proteinRemaining: remaining.protein,
            hasMetProteinTarget: MacroCalculator.hasMetProteinTarget(
                totals: dailyLog.totals,
                targets: targets
            ),
            carbsTarget: targets.carbs,
            carbsConsumed: dailyLog.totals.carbs,
            carbsRemaining: remaining.carbs,
            fatTarget: targets.fat,
            fatConsumed: dailyLog.totals.fat,
            fatRemaining: remaining.fat,
            waterTargetMl: dailyLog.targets.waterTargetMl,
            waterConsumedMl: dailyLog.waterConsumedMl,
            waterRemainingMl: waterRemainingMl,
            hasMetWaterTarget: waterRemainingMl == 0,
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
            notes.append("Calories finished over target.")
        } else {
            notes.append("Calories finished at or under target.")
        }

        if summary.hasMetProteinTarget {
            notes.append("Protein target was met.")
        } else {
            notes.append("Protein target was not met.")
        }

        if summary.hasMetWaterTarget {
            notes.append("Water target was met.")
        } else {
            notes.append("Water target was not met.")
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
