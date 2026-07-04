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
    private static let macroCalorieTolerance = 0.15
    private static let normalMealCalorieMax = 1800.0
    private static let singleItemCalorieMax = 900.0

    static func validate(response: AIFoodEstimateResponse, prompt: String) -> FoodEstimateValidationResult {
        let meals = response.foodLogDrafts
        guard !meals.isEmpty else {
            return .invalid(["Response is missing food log drafts."])
        }

        let listedIngredients = countListedIngredients(in: prompt)
        let promptAnalysis = FoodCompoundDishDetector.analyze(prompt: prompt)
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

            validateCompoundDishDecomposition(
                meal: meal,
                matchedDishes: promptAnalysis.matchedDishes,
                minRequiredComponents: promptAnalysis.minRequiredComponents,
                errors: &errors
            )

            let summed = sumComponents(meal.components)
            if !withinTolerance(actual: meal.totalProtein, expected: summed.protein, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total protein does not match component sum.")
            }
            if !withinTolerance(actual: meal.totalCarbs, expected: summed.carbs, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total carbs do not match component sum.")
            }
            if !withinTolerance(actual: meal.totalFat, expected: summed.fat, absolute: macroTolerance) {
                errors.append("Meal \"\(meal.displayName)\" total fat does not match component sum.")
            }

            if let issue = macroMismatchIssue(
                label: "meal totals",
                calories: meal.totalCalories,
                protein: meal.totalProtein,
                carbs: meal.totalCarbs,
                fat: meal.totalFat
            ) {
                errors.append(issue)
            }

            if summed.calories > normalMealCalorieMax, !promptAnalysis.hasHugePortionHint {
                errors.append(
                    "Meal \"\(meal.displayName)\" calories \(Int(summed.calories)) look too high for a normal portion."
                )
            }

            if meal.components.count == 1,
               summed.calories > singleItemCalorieMax,
               !promptAnalysis.hasHugePortionHint {
                errors.append(
                    "Meal \"\(meal.displayName)\" single-component calories look too high for a normal portion."
                )
            }

            if promptAnalysis.requiresAssumptions {
                let assumptionText = (
                    meal.assumptions + meal.warnings
                ).joined(separator: " ").lowercased()
                if !assumptionText.contains("assumption") && meal.assumptions.isEmpty {
                    errors.append(
                        "Meal \"\(meal.displayName)\" must include assumptions for portion, oil/sauce, confidence, and clarifications."
                    )
                }
            }

            if meal.isMultiComponent, meal.legacyQuantity != nil {
                errors.append("Meal \"\(meal.displayName)\" must not use a single meal-level quantity for mixed components.")
            }

            for component in meal.components {
                if component.sourceText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    errors.append("Component \"\(component.name)\" is missing source text.")
                }
                errors.append(contentsOf: validateComponentMacros(component))
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
        Never collapse multiple listed ingredients or compound dishes into one generic component.
        Do not use the first ingredient quantity as a meal-level quantity.
        Include assumptions for portion, oil/sauce, confidence reason, and clarifications.
        Prefer realistic or slightly conservative calorie estimates.
        All macros must be non-negative and macro calories must match displayed calories within 15%.
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

    private static func validateCompoundDishDecomposition(
        meal: FoodLogDraft,
        matchedDishes: [CompoundDishSpec],
        minRequiredComponents: Int,
        errors: inout [String]
    ) {
        guard !matchedDishes.isEmpty, minRequiredComponents > 1 else { return }

        if meal.components.count < minRequiredComponents {
            let labels = matchedDishes.map(\.label).joined(separator: ", ")
            errors.append(
                "Meal \"\(meal.displayName)\" collapsed compound dish (\(labels)) into \(meal.components.count) component(s); expected at least \(minRequiredComponents)."
            )
            return
        }

        let componentNames = meal.components.map(\.name)
        for dish in matchedDishes where dish.minComponents > 1 {
            if !FoodCompoundDishDetector.componentNamesMatchCompound(componentNames, dish: dish) {
                errors.append(
                    "Meal \"\(meal.displayName)\" components do not reflect expected \(dish.label) decomposition."
                )
            }
        }
    }

    private static func validateComponentMacros(_ component: FoodComponent) -> [String] {
        var issues: [String] = []
        if component.calories < 0 {
            issues.append("Component \"\(component.name)\" has negative calories.")
        }
        if component.protein < 0 {
            issues.append("Component \"\(component.name)\" has negative protein.")
        }
        if component.carbs < 0 {
            issues.append("Component \"\(component.name)\" has negative carbs.")
        }
        if component.fat < 0 {
            issues.append("Component \"\(component.name)\" has negative fat.")
        }
        if let issue = macroMismatchIssue(
            label: component.name,
            calories: component.calories,
            protein: component.protein,
            carbs: component.carbs,
            fat: component.fat
        ) {
            issues.append(issue)
        }
        return issues
    }

    private static func macroMismatchIssue(
        label: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> String? {
        guard calories > 0 else { return nil }
        let computed = protein * 4 + carbs * 4 + fat * 9
        guard computed > 0 else { return nil }
        let delta = abs(computed - Double(calories)) / Double(calories)
        guard delta > macroCalorieTolerance else { return nil }
        return "Macro calories for \(label) do not match displayed calories."
    }

    private static func withinTolerance(actual: Double, expected: Double, absolute: Double) -> Bool {
        let delta = abs(actual - expected)
        if delta <= absolute { return true }
        if expected == 0 { return actual == 0 }
        return delta / abs(expected) <= totalToleranceRatio
    }
}
