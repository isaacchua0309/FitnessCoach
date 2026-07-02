//
//  NutritionSanityValidator.swift
//  Fitness Coach
//
//  FitPilot AI — Detects impossible or suspicious Coach food estimates.
//

import Foundation

struct NutritionSanityResult: Equatable, Sendable {
    var isAcceptable: Bool
    var issues: [String]
    var mealDraft: FoodLogDraft
    var confidence: AIConfidence

    static let underEstimatedUserMessage =
        "This looks under-estimated. Review portions before logging."
}

enum NutritionSanityValidator {

    private static let macroTolerance = 0.15

    private static let dessertTerms = [
        "tiramisu", "cake", "brownie", "cheesecake", "dessert", "pastry", "cookie"
    ]

    private static let dressingTerms = [
        "dressing", "mayo", "mayonnaise", "sesame", "sauce", "aioli"
    ]

    private static let grainTerms = [
        "rice", "barley", "grain", "quinoa", "pasta", "noodle", "couscous"
    ]

    /// Validates a Coach-generated meal draft and downgrades confidence when suspicious.
    static func validate(
        meal: FoodLogDraft,
        prompt: String,
        confidence: AIConfidence
    ) -> NutritionSanityResult {
        var issues: [String] = []
        let normalizedPrompt = prompt.lowercased()

        if let issue = validateMealMacroBalance(meal) {
            issues.append(issue)
        }

        for component in meal.components {
            issues.append(contentsOf: validateComponentMacroBalance(component))
            issues.append(contentsOf: validateCookedChickenBreast(
                component,
                prompt: normalizedPrompt
            ))
            issues.append(contentsOf: validateRichFoodFat(component))
        }

        if meal.components.count > 1 {
            if let issue = validateMinimumCalorieFloor(meal) {
                issues.append(issue)
            }
            if let issue = validateCompositeMixedMealFloor(meal, prompt: normalizedPrompt) {
                issues.append(issue)
            }
        }

        let uniqueIssues = Array(Set(issues)).sorted()
        guard !uniqueIssues.isEmpty else {
            return NutritionSanityResult(
                isAcceptable: true,
                issues: [],
                mealDraft: meal,
                confidence: confidence
            )
        }

        var adjustedMeal = meal
        adjustedMeal.confidence = .low
        var warnings = Set(adjustedMeal.warnings)
        warnings.insert(NutritionSanityResult.underEstimatedUserMessage)
        for issue in uniqueIssues {
            warnings.insert(issue)
        }
        adjustedMeal.warnings = Array(warnings).sorted()

        return NutritionSanityResult(
            isAcceptable: false,
            issues: uniqueIssues,
            mealDraft: adjustedMeal,
            confidence: .low
        )
    }

    // MARK: - Rule 1

    private static func validateMealMacroBalance(_ meal: FoodLogDraft) -> String? {
        guard meal.totalCalories > 0 else { return nil }
        return macroMismatchIssue(
            label: "meal totals",
            calories: meal.totalCalories,
            protein: meal.totalProtein,
            carbs: meal.totalCarbs,
            fat: meal.totalFat
        )
    }

    private static func validateComponentMacroBalance(_ component: FoodComponent) -> [String] {
        guard component.calories > 0 else { return [] }
        if let issue = macroMismatchIssue(
            label: component.name,
            calories: component.calories,
            protein: component.protein,
            carbs: component.carbs,
            fat: component.fat
        ) {
            return [issue]
        }
        return []
    }

    private static func macroMismatchIssue(
        label: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> String? {
        let displayed = Double(calories)
        let computed = macroCalories(protein: protein, carbs: carbs, fat: fat)
        guard displayed > 0, computed > 0 else { return nil }

        let delta = abs(computed - displayed) / displayed
        guard delta > macroTolerance else { return nil }
        return "Macro calories for \(label) do not match displayed calories."
    }

    private static func macroCalories(protein: Double, carbs: Double, fat: Double) -> Double {
        protein * 4 + carbs * 4 + fat * 9
    }

    // MARK: - Rule 2

    private static func validateCookedChickenBreast(
        _ component: FoodComponent,
        prompt: String
    ) -> [String] {
        guard isCookedChickenBreastPortion(component, prompt: prompt) else { return [] }

        var issues: [String] = []
        if component.protein < 40 {
            issues.append("150g cooked chicken breast protein looks too low.")
        }
        if component.calories < 230 {
            issues.append("150g cooked chicken breast calories look too low.")
        }
        return issues
    }

    private static func isCookedChickenBreastPortion(
        _ component: FoodComponent,
        prompt: String
    ) -> Bool {
        let combined = componentSearchText(component, prompt: prompt)
        guard combined.contains("chicken") else { return false }
        guard combined.contains("breast") || combined.contains("chicken breast") else { return false }
        guard combined.contains("cooked") || combined.contains("grilled")
            || combined.contains("roasted") || combined.contains("poached") else {
            return false
        }
        return isApproximatelyGrams(component.quantity, unit: component.unit, target: 150, tolerance: 15)
            || promptContainsGrams(prompt, target: 150, tolerance: 15, keywords: ["chicken"])
    }

    // MARK: - Rule 3

    private static func validateRichFoodFat(_ component: FoodComponent) -> [String] {
        let text = componentSearchText(component, prompt: "")
        var issues: [String] = []

        if dessertTerms.contains(where: { text.contains($0) }) {
            let minimumFat = minimumDessertFat(for: component, text: text)
            if component.fat < minimumFat {
                issues.append("\(component.name) fat looks unrealistically low for a dessert item.")
            }
        }

        if dressingTerms.contains(where: { text.contains($0) }) {
            let minimumFat = minimumDressingFat(for: component)
            if component.fat < minimumFat {
                issues.append("\(component.name) fat looks unrealistically low for a creamy dressing or sauce.")
            }
        }

        return issues
    }

    private static func minimumDessertFat(for component: FoodComponent, text: String) -> Double {
        if isTablespoonPortion(component) {
            return 4
        }
        if isApproximatelyGrams(component.quantity, unit: component.unit, target: 55, tolerance: 15)
            || text.contains("50") || text.contains("60") {
            return 8
        }
        if let quantity = component.quantity, isMassUnit(component.unit), quantity >= 30 {
            return 6
        }
        return 5
    }

    private static func minimumDressingFat(for component: FoodComponent) -> Double {
        if isTablespoonPortion(component) {
            return 4
        }
        if let quantity = component.quantity, isMassUnit(component.unit), quantity >= 10 {
            return 3
        }
        return 2
    }

    // MARK: - Rule 4

    private static func validateMinimumCalorieFloor(_ meal: FoodLogDraft) -> String? {
        let quantified = meal.components.filter { $0.quantity != nil }
        guard quantified.count >= 2 else { return nil }

        let minimumTotal = quantified.reduce(0.0) { partial, component in
            partial + minimumCalories(for: component)
        }
        guard minimumTotal > 0 else { return nil }

        if Double(meal.totalCalories) < minimumTotal * 0.95 {
            return "Total calories are below the sum of obvious component minimums."
        }
        return nil
    }

    private static func minimumCalories(for component: FoodComponent) -> Double {
        let text = componentSearchText(component, prompt: "")
        var minimum = 0.0

        if text.contains("chicken") {
            if isApproximatelyGrams(component.quantity, unit: component.unit, target: 150, tolerance: 20) {
                minimum = max(minimum, 230)
            } else if let quantity = component.quantity, isMassUnit(component.unit) {
                minimum = max(minimum, quantity * 1.5)
            }
        }

        if grainTerms.contains(where: { text.contains($0) }) {
            if isApproximatelyGrams(component.quantity, unit: component.unit, target: 150, tolerance: 20) {
                minimum = max(minimum, 140)
            } else if let quantity = component.quantity, isMassUnit(component.unit) {
                minimum = max(minimum, quantity * 0.9)
            }
        }

        if dressingTerms.contains(where: { text.contains($0) }) {
            minimum = max(minimum, isTablespoonPortion(component) ? 50 : 35)
        }

        if dessertTerms.contains(where: { text.contains($0) }) {
            if isApproximatelyGrams(component.quantity, unit: component.unit, target: 55, tolerance: 15) {
                minimum = max(minimum, 150)
            } else if let quantity = component.quantity, isMassUnit(component.unit), quantity >= 30 {
                minimum = max(minimum, 120)
            } else {
                minimum = max(minimum, 100)
            }
        }

        if minimum == 0, let quantity = component.quantity, isMassUnit(component.unit) {
            minimum = quantity
        } else if minimum == 0, component.calories > 0 {
            minimum = Double(component.calories) * 0.6
        }

        return minimum
    }

    // MARK: - Rule 5

    private static func validateCompositeMixedMealFloor(
        _ meal: FoodLogDraft,
        prompt: String
    ) -> String? {
        let combined = "\(prompt) \(meal.displayName.lowercased()) " +
            meal.components.map { componentSearchText($0, prompt: prompt) }.joined(separator: " ")

        let hasChicken = combined.contains("chicken")
        let hasGrain = grainTerms.contains(where: { combined.contains($0) })
        let hasDressing = dressingTerms.contains(where: { combined.contains($0) })
        let hasDessert = dessertTerms.contains(where: { combined.contains($0) })

        guard hasChicken, hasGrain, hasDressing, hasDessert else { return nil }
        guard meal.totalCalories < 550 else { return nil }
        return "Mixed meal with chicken, grain, dressing, and dessert looks under-estimated."
    }

    // MARK: - Helpers

    private static func componentSearchText(_ component: FoodComponent, prompt: String) -> String {
        [
            component.name,
            component.sourceText,
            component.preparationState,
            component.unit,
            prompt
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
    }

    private static func isApproximatelyGrams(
        _ quantity: Double?,
        unit: String?,
        target: Double,
        tolerance: Double
    ) -> Bool {
        guard let quantity, isMassUnit(unit) else { return false }
        return abs(quantity - target) <= tolerance
    }

    private static func promptContainsGrams(
        _ prompt: String,
        target: Double,
        tolerance: Double,
        keywords: [String]
    ) -> Bool {
        guard keywords.contains(where: { prompt.contains($0) }) else { return false }
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:g|gram|grams)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        let matches = regex.matches(in: prompt, range: range)
        return matches.contains { match in
            guard let valueRange = Range(match.range(at: 1), in: prompt),
                  let value = Double(prompt[valueRange]) else {
                return false
            }
            return abs(value - target) <= tolerance
        }
    }

    private static func isMassUnit(_ unit: String?) -> Bool {
        guard let unit else { return false }
        switch unit.lowercased() {
        case "g", "gram", "grams", "kg":
            return true
        default:
            return false
        }
    }

    private static func isTablespoonPortion(_ component: FoodComponent) -> Bool {
        guard let quantity = component.quantity, let unit = component.unit?.lowercased() else {
            return false
        }
        let isTablespoon = unit.contains("tbsp") || unit.contains("tablespoon")
        return isTablespoon && quantity >= 0.5 && quantity <= 2
    }
}
