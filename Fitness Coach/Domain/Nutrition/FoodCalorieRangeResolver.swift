//
//  FoodCalorieRangeResolver.swift
//  Fitness Coach
//
//  Forma — Resolves and derives calorie ranges for Coach food estimates.
//

import Foundation

enum FoodCalorieRangeResolutionSource: Equatable, Sendable {
    case explicit
    case derivedFromConfidence
    case repaired
}

struct FoodCalorieRangeResolution: Equatable, Sendable {
    var lower: Int
    var upper: Int
    var source: FoodCalorieRangeResolutionSource
    var warning: String?
}

enum FoodCalorieRangeResolver {

    // Confidence-based fallback margins when the backend omits explicit bounds.
    // High confidence: ±10–15% total spread (12.5% margin each side).
    // Medium confidence: ±20–25% total spread (22.5% margin each side).
    // Low confidence: ±30–40% total spread (35% margin each side).
    // Minimum spreads keep tiny meals from showing implausibly tight ranges.
    private static let marginByConfidence: [ConfidenceLevel: Double] = [
        .high: 0.125,
        .medium: 0.225,
        .low: 0.35
    ]

    private static let minimumSpreadByConfidence: [ConfidenceLevel: Int] = [
        .high: 10,
        .medium: 20,
        .low: 40
    ]

    static func resolvedRange(for meal: FoodLogDraft) -> (lower: Int, upper: Int)? {
        let resolution = resolve(
            totalCalories: meal.totalCalories,
            confidence: meal.confidence,
            lower: meal.calorieRangeLower,
            upper: meal.calorieRangeUpper
        )
        return (resolution.lower, resolution.upper)
    }

    static func resolve(
        totalCalories: Int,
        confidence: ConfidenceLevel,
        lower: Int?,
        upper: Int?
    ) -> FoodCalorieRangeResolution {
        let roundedCalories = max(0, totalCalories)

        if let lower, let upper, lower >= 0, upper >= lower {
            if let repaired = repairIfNeeded(
                totalCalories: roundedCalories,
                confidence: confidence,
                lower: lower,
                upper: upper
            ) {
                return repaired
            }
            return FoodCalorieRangeResolution(
                lower: lower,
                upper: upper,
                source: .explicit,
                warning: nil
            )
        }

        if let lower, let upper, lower >= 0, upper < lower {
            let swappedLower = upper
            let swappedUpper = lower
            if let repaired = repairIfNeeded(
                totalCalories: roundedCalories,
                confidence: confidence,
                lower: swappedLower,
                upper: swappedUpper
            ) {
                return repaired
            }
            return FoodCalorieRangeResolution(
                lower: swappedLower,
                upper: swappedUpper,
                source: .repaired,
                warning: "Calorie range bounds were reversed and repaired."
            )
        }

        if let partialLower = lower ?? upper, partialLower >= 0, roundedCalories > 0 {
            let derived = derivedRange(totalCalories: roundedCalories, confidence: confidence)
            let repairedLower = min(partialLower, derived.lower)
            let repairedUpper = max(partialLower, derived.upper)
            return FoodCalorieRangeResolution(
                lower: repairedLower,
                upper: repairedUpper,
                source: .repaired,
                warning: "Calorie range was incomplete and expanded using confidence heuristics."
            )
        }

        guard let derived = derivedRange(totalCalories: roundedCalories, confidence: confidence) else {
            return FoodCalorieRangeResolution(
                lower: 0,
                upper: 0,
                source: .derivedFromConfidence,
                warning: "Calorie range could not be derived because total calories are missing."
            )
        }

        return FoodCalorieRangeResolution(
            lower: derived.lower,
            upper: derived.upper,
            source: .derivedFromConfidence,
            warning: nil
        )
    }

    static func derivedRange(
        totalCalories: Int,
        confidence: ConfidenceLevel
    ) -> (lower: Int, upper: Int)? {
        guard totalCalories > 0 else { return nil }

        let margin = marginByConfidence[confidence] ?? marginByConfidence[.medium] ?? 0.225
        let minimumSpread = minimumSpreadByConfidence[confidence] ?? minimumSpreadByConfidence[.medium] ?? 20
        let spread = max(minimumSpread, Int((Double(totalCalories) * margin).rounded(.toNearestOrAwayFromZero)))

        return (
            lower: max(0, totalCalories - spread),
            upper: totalCalories + spread
        )
    }

    static func minimumSpread(totalCalories: Int, confidence: ConfidenceLevel) -> Int {
        let roundedCalories = max(0, totalCalories)
        let margin = marginByConfidence[confidence] ?? marginByConfidence[.medium] ?? 0.225
        let minimumSpread = minimumSpreadByConfidence[confidence] ?? minimumSpreadByConfidence[.medium] ?? 20
        return max(minimumSpread, Int((Double(roundedCalories) * margin).rounded(.toNearestOrAwayFromZero)))
    }

    // MARK: - Private

    private static func repairIfNeeded(
        totalCalories: Int,
        confidence: ConfidenceLevel,
        lower: Int,
        upper: Int
    ) -> FoodCalorieRangeResolution? {
        var repairedLower = max(0, lower)
        var repairedUpper = max(0, upper)
        var warnings: [String] = []

        if lower < 0 || upper < 0 {
            warnings.append("Negative calorie range bounds were clamped to zero.")
        }

        if totalCalories > 0 {
            if repairedLower > totalCalories {
                repairedLower = max(0, totalCalories - minimumSpread(totalCalories: totalCalories, confidence: confidence) / 2)
                warnings.append("Calorie range lower bound exceeded the estimate and was widened.")
            }
            if repairedUpper < totalCalories {
                repairedUpper = totalCalories + minimumSpread(totalCalories: totalCalories, confidence: confidence) / 2
                warnings.append("Calorie range upper bound was below the estimate and was widened.")
            }

            let width = repairedUpper - repairedLower
            let minWidth = minimumSpread(totalCalories: totalCalories, confidence: confidence)
            if totalCalories >= 80, width < minWidth, let derived = derivedRange(totalCalories: totalCalories, confidence: confidence) {
                repairedLower = min(repairedLower, derived.lower)
                repairedUpper = max(repairedUpper, derived.upper)
                warnings.append("Calorie range was too narrow for \(confidence.rawValue) confidence and was widened.")
            }
        }

        if warnings.isEmpty {
            return nil
        }

        if repairedLower > repairedUpper {
            guard let derived = derivedRange(totalCalories: totalCalories, confidence: confidence) else {
                return FoodCalorieRangeResolution(
                    lower: 0,
                    upper: 0,
                    source: .repaired,
                    warning: (warnings + ["Calorie range could not be repaired safely."]).joined(separator: " ")
                )
            }
            return FoodCalorieRangeResolution(
                lower: derived.lower,
                upper: derived.upper,
                source: .repaired,
                warning: (warnings + ["Calorie range was re-derived after unsafe bounds."]).joined(separator: " ")
            )
        }

        return FoodCalorieRangeResolution(
            lower: repairedLower,
            upper: repairedUpper,
            source: .repaired,
            warning: warnings.joined(separator: " ")
        )
    }
}
