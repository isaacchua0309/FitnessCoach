//
//  MacroCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic macro and daily nutrition arithmetic.
//

import Foundation

struct MacroCalculator {

    // MARK: Totals

    static func totals(from foodEntries: [FoodEntry]) -> MacroTotals {
        var calories = 0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        var fiber = 0.0
        var sodium = 0.0
        var hasFiber = false
        var hasSodium = false

        for entry in foodEntries {
            calories += entry.calories
            protein += entry.protein
            carbs += entry.carbs
            fat += entry.fat
            if let entryFiber = entry.fiber {
                fiber += entryFiber
                hasFiber = true
            }
            if let entrySodium = entry.sodium {
                sodium += entrySodium
                hasSodium = true
            }
        }

        return MacroTotals(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: hasFiber ? fiber : nil,
            sodium: hasSodium ? sodium : nil
        )
    }

    // MARK: Remaining

    static func remaining(targets: MacroTargets, totals: MacroTotals) -> MacroRemaining {
        MacroRemaining(
            calories: targets.calories - totals.calories,
            protein: targets.protein - totals.protein,
            carbs: targets.carbs - totals.carbs,
            fat: targets.fat - totals.fat
        )
    }

    static func remaining(userTargets: UserTargets, totals: MacroTotals) -> MacroRemaining {
        remaining(targets: macroTargets(from: userTargets), totals: totals)
    }

    // MARK: Conversion

    static func macroTargets(from userTargets: UserTargets) -> MacroTargets {
        MacroTargets(
            calories: userTargets.calorieTarget,
            protein: userTargets.proteinTarget,
            carbs: userTargets.carbTarget,
            fat: userTargets.fatTarget
        )
    }

    // MARK: Progress

    /// Returns a clamped 0...1 progress ratio. A zero or negative target yields 0
    /// to avoid division by zero.
    static func progress(consumed: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        let ratio = consumed / target
        return min(max(ratio, 0), 1)
    }

    static func calorieProgress(totals: MacroTotals, targets: MacroTargets) -> Double {
        progress(consumed: Double(totals.calories), target: Double(targets.calories))
    }

    static func proteinProgress(totals: MacroTotals, targets: MacroTargets) -> Double {
        progress(consumed: totals.protein, target: targets.protein)
    }

    // MARK: Detection

    static func isOverCalories(totals: MacroTotals, targets: MacroTargets) -> Bool {
        totals.calories > targets.calories
    }

    static func hasMetProteinTarget(totals: MacroTotals, targets: MacroTargets) -> Bool {
        guard targets.protein > 0 else { return true }
        return totals.protein >= targets.protein
    }
}
