//
//  FoodCalorieRange.swift
//  Fitness Coach
//
//  Derives and validates calorie estimate ranges by confidence level.
//

import Foundation

struct FoodCalorieRange: Equatable, Sendable {
    var lower: Int
    var upper: Int

    var width: Int {
        max(0, upper - lower)
    }
}

enum FoodCalorieRangePolicy {

    private static let minRangeWidth: [AIConfidence: Int] = [
        .high: 10,
        .medium: 20,
        .low: 40,
    ]

    private static let rangeMargin: [AIConfidence: Double] = [
        .high: 0.05,
        .medium: 0.12,
        .low: 0.20,
    ]

    static func derive(calories: Int, confidence: AIConfidence) -> FoodCalorieRange {
        let roundedCalories = max(0, calories)
        let margin = rangeMargin[confidence] ?? rangeMargin[.medium]!
        let minWidth = minRangeWidth[confidence] ?? minRangeWidth[.medium]!
        let spread = max(minWidth, Int((Double(roundedCalories) * margin).rounded()))
        return FoodCalorieRange(
            lower: max(0, roundedCalories - spread),
            upper: roundedCalories + spread
        )
    }

    static func resolve(
        calories: Int,
        confidence: AIConfidence,
        explicitLower: Int?,
        explicitUpper: Int?
    ) -> FoodCalorieRange {
        if let explicitLower,
           let explicitUpper,
           explicitLower >= 0,
           explicitUpper >= explicitLower {
            return FoodCalorieRange(lower: explicitLower, upper: explicitUpper)
        }
        return derive(calories: calories, confidence: confidence)
    }

    static func minimumWidth(calories: Int, confidence: AIConfidence) -> Int {
        let roundedCalories = max(0, calories)
        let margin = rangeMargin[confidence] ?? rangeMargin[.medium]!
        let minWidth = minRangeWidth[confidence] ?? minRangeWidth[.medium]!
        return max(minWidth, Int((Double(roundedCalories) * margin).rounded()))
    }

    static func isWideEnough(
        calories: Int,
        lower: Int,
        upper: Int,
        confidence: AIConfidence
    ) -> Bool {
        guard calories >= 80 else { return true }
        return (upper - lower) >= minimumWidth(calories: calories, confidence: confidence)
    }

    static func widenForUncertainty(
        calories: Int,
        confidence: AIConfidence,
        lower: Int,
        upper: Int,
        upwardBias: Int = 0
    ) -> FoodCalorieRange {
        let derived = derive(calories: calories, confidence: confidence)
        let widenedLower = min(lower, derived.lower)
        var widenedUpper = max(upper, derived.upper)
        if upwardBias > 0 {
            widenedUpper = max(widenedUpper, calories + upwardBias)
        }
        return FoodCalorieRange(lower: widenedLower, upper: widenedUpper)
    }
}
