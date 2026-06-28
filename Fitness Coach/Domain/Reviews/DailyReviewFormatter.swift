//
//  DailyReviewFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic review section formatting.
//
//  Formatting only. No service calls, no persistence, and no AI.
//

import Foundation

enum DailyReviewFormatter {

    static func caloriesSummary(from summary: DailyReviewSummary) -> String {
        if summary.isOverCalorieTarget {
            return "Calories: \(summary.caloriesConsumed) / \(summary.calorieTarget) kcal. You are \(abs(summary.caloriesRemaining)) kcal over target."
        }
        return "Calories: \(summary.caloriesConsumed) / \(summary.calorieTarget) kcal. You have \(summary.caloriesRemaining) kcal remaining."
    }

    static func proteinSummary(from summary: DailyReviewSummary) -> String {
        let consumed = FoodEntryFormFormatter.formatMacro(summary.proteinConsumed)
        let target = FoodEntryFormFormatter.formatMacro(summary.proteinTarget)
        if summary.hasMetProteinTarget {
            return "Protein: \(consumed) / \(target)g. You met your protein target."
        }
        return "Protein: \(consumed) / \(target)g. You are \(FoodEntryFormFormatter.formatMacro(max(summary.proteinRemaining, 0)))g short of target."
    }

    static func hydrationSummary(from summary: DailyReviewSummary) -> String {
        if summary.hasMetWaterTarget {
            return "Water: \(summary.waterConsumedMl) / \(summary.waterTargetMl)ml. You met your hydration target."
        }
        return "Water: \(summary.waterConsumedMl) / \(summary.waterTargetMl)ml. You have \(summary.waterRemainingMl)ml remaining."
    }

    static func workoutSummary(from summary: DailyReviewSummary) -> String? {
        guard summary.hasWorkout else { return nil }
        let label = summary.workoutCount == 1 ? "session" : "sessions"
        return "Workout: \(summary.workoutCount) \(label) logged, estimated \(summary.workoutCaloriesBurned) kcal burned."
    }

    static func weightSummary(from summary: DailyReviewSummary) -> String? {
        if let weightKg = summary.weightKg {
            return "Weight logged: \(FoodEntryFormFormatter.formatWeight(weightKg)) kg."
        }
        if let latestWeightKg = summary.latestWeightKg {
            return "Latest weight: \(FoodEntryFormFormatter.formatWeight(latestWeightKg)) kg."
        }
        return nil
    }

    static func tomorrowRecommendation(from summary: DailyReviewSummary) -> String {
        if !summary.hasMetProteinTarget {
            return "Prioritize lean protein earlier tomorrow."
        }
        if !summary.hasMetWaterTarget {
            return "Start hydration earlier tomorrow."
        }
        if summary.isOverCalorieTarget {
            return "Plan a higher-satiety lunch and keep the weekly average in mind."
        }
        return "Repeat the same structure tomorrow and keep logging consistently."
    }

    static func fallbackSummaryText() -> String {
        "Today's review is available, but AI coaching is temporarily unavailable. Your calories, macros, water, and workout totals are summarized below."
    }

    static func coachMessage(from review: DailyReview) -> String {
        var sections = [
            "Daily Review",
            "",
            review.caloriesSummary,
            review.proteinSummary,
            review.hydrationSummary
        ]

        if let workoutSummary = review.workoutSummary {
            sections.append(workoutSummary)
        }
        if let weightSummary = review.weightSummary {
            sections.append(weightSummary)
        }

        sections += [
            "",
            "Coach note:",
            review.summaryText,
            "",
            "Tomorrow:",
            review.tomorrowRecommendation
        ]

        return sections.joined(separator: "\n")
    }

    static func dailyReviewAIInput(from summary: DailyReviewSummary) -> DailyReviewAIInput {
        DailyReviewAIInput(
            date: summary.date,
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
            latestWeightKg: summary.latestWeightKg,
            steps: summary.steps,
            workoutCount: summary.workoutCount,
            workoutCaloriesBurned: summary.workoutCaloriesBurned,
            foodEntryCount: summary.foodEntryCount,
            lowConfidenceFoodCount: summary.lowConfidenceFoodCount,
            topProteinFoodNames: summary.topProteinFoodNames,
            deterministicNotes: summary.deterministicNotes
        )
    }
}
