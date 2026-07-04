//
//  FoodCalorieRangeResolver.swift
//  Fitness Coach
//
//  FitPilot AI — Resolves calorie ranges for Coach food estimates.
//

import Foundation

enum FoodCalorieRangeResolver {

    /// Returns an explicit or confidence-derived calorie range for display and trust UX.
    static func resolvedRange(for meal: FoodLogDraft) -> (lower: Int, upper: Int)? {
        if let lower = meal.caloriesRangeLower,
           let upper = meal.caloriesRangeUpper,
           lower >= 0,
           upper >= lower {
            return (lower, upper)
        }
        return derivedRange(totalCalories: meal.totalCalories, confidence: meal.confidence)
    }

    /// Fills missing range fields using the scalar total and confidence bucket.
    static func fillMissingRanges(_ meal: FoodLogDraft) -> FoodLogDraft {
        guard meal.caloriesRangeLower == nil || meal.caloriesRangeUpper == nil else {
            return meal
        }
        guard let range = derivedRange(totalCalories: meal.totalCalories, confidence: meal.confidence) else {
            return meal
        }
        var updated = meal
        updated.caloriesRangeLower = range.lower
        updated.caloriesRangeUpper = range.upper
        return updated
    }

    static func derivedRange(
        totalCalories: Int,
        confidence: ConfidenceLevel
    ) -> (lower: Int, upper: Int)? {
        guard totalCalories > 0 else { return nil }

        let margin: Double
        switch confidence {
        case .high:
            margin = 0.05
        case .medium:
            margin = 0.12
        case .low:
            margin = 0.20
        }

        let spread = max(10, Int((Double(totalCalories) * margin).rounded()))
        return (
            lower: max(0, totalCalories - spread),
            upper: totalCalories + spread
        )
    }
}
