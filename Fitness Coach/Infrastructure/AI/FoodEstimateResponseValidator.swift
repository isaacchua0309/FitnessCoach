//
//  FoodEstimateResponseValidator.swift
//  Fitness Coach
//
//  FitPilot AI — Validates structured food estimate responses before presentation.
//

import Foundation

enum FoodEstimateValidationResult: Equatable, Sendable {
    case valid
    case invalid([String])

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errors: [String] {
        if case .invalid(let errors) = self { return errors }
        return []
    }
}

enum FoodEstimateResponseValidator {

    private static let totalToleranceRatio = 0.05
    private static let calorieTolerance = 3.0
    private static let macroTolerance = 1.0

    static func validate(response: AIFoodEstimateResponse, prompt: String) -> FoodEstimateValidationResult {
        let meals = response.foodLogDrafts
        guard !meals.isEmpty else {
            return .invalid(["Response is missing food log drafts."])
        }

        let listedIngredients = countListedIngredients(in: prompt)
        var errors: [String] = []

        for meal in meals {
            if meal.components.isEmpty {
                errors.append("Meal \"\(meal.displayName)\" is missing components.")
                continue
            }

            if listedIngredients >= 2, meal.components.count < 2 {
                errors.append(
                    "Meal \"\(meal.displayName)\" collapsed \(listedIngredients) listed ingredients into \(meal.components.count) component(s)."
                )
            }

            let summed = sumComponents(meal.components)
            if !withinTolerance(
                actual: Double(meal.totalCalories),
                expected: summed.calories,
                absolute: calorieTolerance
            ) {
                errors.append(
                    "Meal \"\(meal.displayName)\" total calories \(meal.totalCalories) do not match component sum \(Int(summed.calories))."
                )
            }
            if !withinTolerance(actual: meal.totalProtein, expected: summed.protein, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total protein does not match component sum.")
            }
            if !withinTolerance(actual: meal.totalCarbs, expected: summed.carbs, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total carbs do not match component sum.")
            }
            if !withinTolerance(actual: meal.totalFat, expected: summed.fat, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total fat does not match component sum.")
            }

            if meal.isMultiComponent, meal.legacyQuantity != nil {
                errors.append("Meal \"\(meal.displayName)\" must not use a single meal-level quantity for mixed components.")
            }

            for component in meal.components where component.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                errors.append("Component \"\(component.name)\" is missing source text.")
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }

    static func repairPrompt(original: String, errors: [String]) -> String {
        let repairBlock = errors.map { "- \($0)" }.joined(separator: "\n")
        return """
        \(original)

        REPAIR REQUIRED. Return strict per-ingredient JSON components and totals that equal the component sums.
        Previous response failed validation:
        \(repairBlock)
        Never collapse multiple listed ingredients into one generic component.
        Do not use the first ingredient quantity as a meal-level quantity.
        Prefer realistic or slightly conservative calorie estimates.
        """
    }

    // MARK: - Private

    private static func countListedIngredients(in text: String) -> Int {
        FoodListedIngredientCounter.count(in: text)
    }

    private static func sumComponents(_ components: [FoodComponent]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        components.reduce((0, 0, 0, 0)) { partial, component in
            (
                partial.0 + Double(component.calories),
                partial.1 + component.protein,
                partial.2 + component.carbs,
                partial.3 + component.fat
            )
        }
    }

    private static func withinTolerance(actual: Double, expected: Double, absolute: Double) -> Bool {
        let delta = abs(actual - expected)
        if delta <= absolute { return true }
        if expected == 0 { return actual == 0 }
        return delta / abs(expected) <= totalToleranceRatio
    }
}
