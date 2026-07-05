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
    var repairedMacros: Bool

    static let underEstimatedUserMessage =
        "This looks under-estimated. Review portions before logging."

    static let collapsedCompoundDishUserMessage =
        "This compound dish may be missing components — review before logging."

    static let clarificationRequiredUserMessage =
        "This estimate needs clarification before logging."

    static let lowConfidenceReviewUserMessage =
        FoodCompoundDishDetector.lowConfidenceReviewMessage
}

enum NutritionSanityValidator {

    private static let macroTolerance = 0.15
    private static let macroRepairTolerance = 0.15

    private static let dessertTerms = [
        "tiramisu", "cake", "brownie", "cheesecake", "dessert", "pastry", "cookie"
    ]

    private static let dressingTerms = [
        "dressing", "mayo", "mayonnaise", "sesame", "sauce", "aioli"
    ]

    private static let sauceOilTerms = [
        "sauce", "oil", "dressing", "mayo", "mayonnaise", "sambal", "gravy",
        "curry sauce", "chili", "aioli", "sesame"
    ]

    private static let grainTerms = [
        "rice", "barley", "grain", "quinoa", "pasta", "noodle", "couscous"
    ]

    private static let smallPortionTerms = [
        "small", "half", "light", "kid", "snack", "tasting", "mini", "petite"
    ]

    private static let oilSauceDishIDs: Set<String> = [
        "chicken_rice", "nasi_lemak", "mala", "char_kway_teow", "ban_mian", "cai_fan"
    ]

    private struct DishCalorieFloor {
        let pattern: String
        let minimumCalories: Int
        let allowsSmallPortion: Bool
    }

    private static let dishCalorieFloors: [DishCalorieFloor] = [
        DishCalorieFloor(pattern: #"chicken rice|hainanese chicken"#, minimumCalories: 350, allowsSmallPortion: true),
        DishCalorieFloor(pattern: #"char kway teow|char kway"#, minimumCalories: 450, allowsSmallPortion: true),
        DishCalorieFloor(pattern: #"\bmala\b|malatang"#, minimumCalories: 500, allowsSmallPortion: true),
    ]

    /// Validates a Coach-generated meal draft and downgrades confidence when suspicious.
    static func validate(
        meal: FoodLogDraft,
        prompt: String,
        confidence: AIConfidence
    ) -> NutritionSanityResult {
        var issues: [String] = []
        var uncertaintyReasons = uniqueStrings(meal.uncertaintyReasons)
        var assumptions = uniqueStrings(meal.assumptions)
        var suggestedClarifications = uniqueStrings(meal.suggestedClarifications)
        var adjustedMeal = meal
        var adjustedConfidence = confidence
        var repairedMacros = false
        var requiresClarification = meal.requiresClarificationBeforeLogging
        let normalizedPrompt = prompt.lowercased()
        let explicitPortions = explicitPortionHints(in: normalizedPrompt)

        var components = meal.components
        for index in components.indices {
            switch repairComponentMacroMismatchIfSafe(
                &components[index],
                explicitPortions: explicitPortions
            ) {
            case .repaired(let reason):
                repairedMacros = true
                if let reason {
                    uncertaintyReasons.append(reason)
                }
            case .none:
                issues.append(contentsOf: validateComponentMacroBalance(components[index]))
            }
            issues.append(contentsOf: validateCookedChickenBreast(
                components[index],
                prompt: normalizedPrompt,
                explicitPortions: explicitPortions
            ))
            issues.append(contentsOf: validateRichFoodFat(components[index]))
        }
        adjustedMeal.components = components

        if let issue = validateMealMacroBalance(adjustedMeal) {
            issues.append(issue)
        }

        if adjustedMeal.components.count > 1 {
            if let issue = validateMinimumCalorieFloor(adjustedMeal) {
                issues.append(issue)
            }
            if let issue = validateCompositeMixedMealFloor(adjustedMeal, prompt: normalizedPrompt) {
                issues.append(issue)
            }
        }

        issues.append(contentsOf: validateDishCalorieFloors(
            adjustedMeal,
            prompt: normalizedPrompt
        ))
        issues.append(contentsOf: validateChickenBreastByWeight(
            adjustedMeal,
            prompt: normalizedPrompt,
            explicitPortions: explicitPortions
        ))
        issues.append(contentsOf: validateMilkVolumeEstimate(
            adjustedMeal,
            prompt: normalizedPrompt,
            explicitPortions: explicitPortions
        ))

        if let hiddenOil = applyHiddenOilSaucePolicy(
            meal: &adjustedMeal,
            prompt: normalizedPrompt,
            uncertaintyReasons: &uncertaintyReasons,
            assumptions: &assumptions
        ) {
            issues.append(hiddenOil)
        }

        if let issue = validateCollapsedCompoundDish(adjustedMeal, prompt: normalizedPrompt) {
            issues.append(issue)
        }

        for component in adjustedMeal.components {
            issues.append(contentsOf: validateNonNegativeMacros(component))
        }

        let uniqueIssues = uniqueStrings(issues)
        let shouldDowngrade = !uniqueIssues.isEmpty

        if shouldDowngrade {
            adjustedConfidence = .low
            adjustedMeal.confidence = .low
            requiresClarification = true
        }

        adjustedConfidence = applyLowConfidencePolicy(
            confidence: adjustedConfidence,
            meal: adjustedMeal,
            uncertaintyReasons: &uncertaintyReasons,
            assumptions: &assumptions,
            issues: uniqueIssues
        )

        adjustedMeal.confidence = confidenceLevel(from: adjustedConfidence)
        adjustedMeal.uncertaintyReasons = uncertaintyReasons
        adjustedMeal.assumptions = assumptions
        adjustedMeal.suggestedClarifications = suggestedClarifications
        adjustedMeal.requiresClarificationBeforeLogging = applyClarificationPolicy(
            requiresClarification: requiresClarification,
            confidence: adjustedConfidence,
            uncertaintyReasons: uncertaintyReasons,
            suggestedClarifications: &suggestedClarifications
        )
        adjustedMeal.suggestedClarifications = suggestedClarifications
        adjustedMeal.primaryUncertainty = adjustedMeal.primaryUncertainty
            ?? uncertaintyReasons.first
            ?? suggestedClarifications.first

        let calorieRange = finalizeCalorieRange(
            meal: adjustedMeal,
            confidence: adjustedConfidence,
            shouldWiden: shouldDowngrade || adjustedConfidence == .low
        )
        adjustedMeal.calorieRangeLower = calorieRange.lower
        adjustedMeal.calorieRangeUpper = calorieRange.upper

        var warnings = Set(adjustedMeal.warnings)
        if shouldDowngrade {
            warnings.insert(NutritionSanityResult.underEstimatedUserMessage)
            for issue in uniqueIssues {
                warnings.insert(issue)
            }
        }
        if adjustedConfidence == .low {
            warnings.insert(NutritionSanityResult.lowConfidenceReviewUserMessage)
        }
        if adjustedMeal.requiresClarificationBeforeLogging {
            warnings.insert(NutritionSanityResult.clarificationRequiredUserMessage)
        }
        for reason in uncertaintyReasons {
            warnings.insert(reason)
        }
        adjustedMeal.warnings = Array(warnings).sorted()

        return NutritionSanityResult(
            isAcceptable: !shouldDowngrade,
            issues: uniqueIssues,
            mealDraft: adjustedMeal,
            confidence: presentationConfidence(
                raw: adjustedConfidence,
                requiresClarification: adjustedMeal.requiresClarificationBeforeLogging
            ),
            repairedMacros: repairedMacros
        )
    }

    static func presentationConfidence(
        raw: AIConfidence,
        requiresClarification: Bool
    ) -> AIConfidence {
        guard requiresClarification else { return raw }
        switch raw {
        case .high, .medium:
            return .low
        case .low:
            return .low
        }
    }

    // MARK: - Rule 1

    private enum MacroRepairResult: Equatable {
        case none
        case repaired(uncertaintyReason: String?)
    }

    private static func repairComponentMacroMismatchIfSafe(
        _ component: inout FoodComponent,
        explicitPortions: [ExplicitPortionHint]
    ) -> MacroRepairResult {
        guard component.calories > 0 else { return .none }
        let computed = macroCalories(
            protein: component.protein,
            carbs: component.carbs,
            fat: component.fat
        )
        guard computed > 0 else { return .none }

        let displayed = Double(component.calories)
        let delta = abs(computed - displayed) / displayed
        guard delta > 0, delta <= macroRepairTolerance else { return .none }
        guard preservesExplicitPortion(component, explicitPortions: explicitPortions) else { return .none }

        component.calories = Int(computed.rounded())
        if delta > 0.05 {
            return .repaired(
                uncertaintyReason: "Adjusted \(component.name) calories to match macros."
            )
        }
        return .repaired(uncertaintyReason: nil)
    }

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

    private static func validateDishCalorieFloors(
        _ meal: FoodLogDraft,
        prompt: String
    ) -> [String] {
        guard !hasSmallPortionHint(prompt) else { return [] }
        let combined = combinedMealText(meal, prompt: prompt)
        var issues: [String] = []

        for floor in dishCalorieFloors {
            guard matchesPattern(floor.pattern, in: combined) else { continue }
            if meal.totalCalories < floor.minimumCalories {
                issues.append(
                    "\(meal.displayName) calories look too low for a normal portion of this dish."
                )
            }
        }
        return issues
    }

    private static func validateChickenBreastByWeight(
        _ meal: FoodLogDraft,
        prompt: String,
        explicitPortions: [ExplicitPortionHint]
    ) -> [String] {
        var issues: [String] = []
        for component in meal.components {
            guard let grams = resolvedGramWeight(for: component, prompt: prompt, explicitPortions: explicitPortions),
                  grams >= 250 else {
                continue
            }
            let combined = componentSearchText(component, prompt: prompt)
            guard combined.contains("chicken"),
                  combined.contains("breast") || combined.contains("chicken breast") else {
                continue
            }

            let minimumCalories = Int((grams * 1.53).rounded())
            let minimumProtein = grams * 0.27
            if component.calories < minimumCalories {
                issues.append("\(Int(grams))g chicken breast calories look too low.")
            }
            if component.protein < minimumProtein {
                issues.append("\(Int(grams))g chicken breast protein looks too low.")
            }
        }
        return issues
    }

    private static func validateMilkVolumeEstimate(
        _ meal: FoodLogDraft,
        prompt: String,
        explicitPortions: [ExplicitPortionHint]
    ) -> [String] {
        let combined = combinedMealText(meal, prompt: prompt)
        guard combined.contains("milk") else { return [] }
        guard combined.contains("full cream")
            || combined.contains("whole milk")
            || combined.contains("full-cream")
            || (combined.contains("milk") && !combined.contains("skim") && !combined.contains("low fat")) else {
            return []
        }

        let targetML = explicitPortions.first(where: { $0.unit == "ml" })?.value
            ?? meal.components.compactMap { component -> Double? in
                guard isVolumeUnit(component.unit), let quantity = component.quantity else { return nil }
                return quantity
            }.max()

        guard let ml = targetML, ml >= 450 else { return [] }

        let minimumCalories = Int((ml * 0.50).rounded())
        let maximumCalories = Int((ml * 0.75).rounded())
        if meal.totalCalories < minimumCalories || meal.totalCalories > maximumCalories {
            return ["\(Int(ml))ml full cream milk calories look outside a sensible range."]
        }
        return []
    }

    private static func validateCookedChickenBreast(
        _ component: FoodComponent,
        prompt: String,
        explicitPortions: [ExplicitPortionHint]
    ) -> [String] {
        guard isCookedChickenBreastPortion(
            component,
            prompt: prompt,
            explicitPortions: explicitPortions
        ) else { return [] }

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
        prompt: String,
        explicitPortions: [ExplicitPortionHint]
    ) -> Bool {
        let combined = componentSearchText(component, prompt: prompt)
        guard combined.contains("chicken") else { return false }
        guard combined.contains("breast") || combined.contains("chicken breast") else { return false }
        guard combined.contains("cooked") || combined.contains("grilled")
            || combined.contains("roasted") || combined.contains("poached") else {
            return false
        }

        if isApproximatelyGrams(component.quantity, unit: component.unit, target: 150, tolerance: 15) {
            return true
        }
        return explicitPortions.contains { hint in
            hint.unit == "g" && abs(hint.value - 150) <= 15 && combined.contains("chicken")
        }
    }

    // MARK: - Rule 3

    private static func applyHiddenOilSaucePolicy(
        meal: inout FoodLogDraft,
        prompt: String,
        uncertaintyReasons: inout [String],
        assumptions: inout [String]
    ) -> String? {
        let analysis = FoodCompoundDishDetector.analyze(prompt: prompt)
        let relevantDishes = analysis.matchedDishes.filter { oilSauceDishIDs.contains($0.id) }
        guard !relevantDishes.isEmpty else { return nil }

        let componentText = meal.components
            .map { componentSearchText($0, prompt: prompt) }
            .joined(separator: " ")
        guard !sauceOilTerms.contains(where: { componentText.contains($0) }) else { return nil }

        let reason = "Hidden oil or sauce is likely but was not estimated separately."
        uncertaintyReasons.append(reason)
        assumptions.append("Assumed standard cooking oil/sauce for \(relevantDishes.map(\.label).joined(separator: ", ")).")

        let upwardBias = relevantDishes.contains { $0.id == "mala" || $0.id == "char_kway_teow" } ? 120 : 80
        let range = FoodCalorieRangePolicy.widenForUncertainty(
            calories: meal.totalCalories,
            confidence: .low,
            lower: meal.calorieRangeLower ?? meal.resolvedCalorieRange.lower,
            upper: meal.calorieRangeUpper ?? meal.resolvedCalorieRange.upper,
            upwardBias: upwardBias
        )
        meal.calorieRangeLower = range.lower
        meal.calorieRangeUpper = range.upper

        if meal.totalCalories < hiddenOilMinimumCalories(for: relevantDishes) {
            let estimated = estimatedHiddenOilComponent(for: relevantDishes)
            meal.components.append(estimated)
            return "Compound dish appears to be missing oil/sauce calories."
        }

        return "Compound dish may be missing oil/sauce component."
    }

    private static func hiddenOilMinimumCalories(for dishes: [CompoundDishSpec]) -> Int {
        if dishes.contains(where: { $0.id == "mala" }) { return 500 }
        if dishes.contains(where: { $0.id == "char_kway_teow" }) { return 450 }
        if dishes.contains(where: { $0.id == "chicken_rice" }) { return 350 }
        return 400
    }

    private static func estimatedHiddenOilComponent(for dishes: [CompoundDishSpec]) -> FoodComponent {
        let calories: Int
        let fat: Double
        if dishes.contains(where: { $0.id == "mala" || $0.id == "char_kway_teow" }) {
            calories = 90
            fat = 10
        } else {
            calories = 60
            fat = 7
        }
        return FoodComponent(
            name: "estimated cooking oil/sauce",
            calories: calories,
            protein: 0,
            carbs: 1,
            fat: fat,
            confidence: .low,
            sourceText: "Hidden oil/sauce allowance for local dish estimate."
        )
    }

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

    // MARK: - Rule 4

    private static func applyLowConfidencePolicy(
        confidence: AIConfidence,
        meal: FoodLogDraft,
        uncertaintyReasons: inout [String],
        assumptions: inout [String],
        issues: [String]
    ) -> AIConfidence {
        guard confidence == .low || meal.confidence == .low else { return confidence }

        if uncertaintyReasons.isEmpty {
            uncertaintyReasons.append(defaultUncertaintyReason(for: .low))
        }
        if assumptions.isEmpty, !meal.warnings.isEmpty {
            assumptions.append(contentsOf: meal.warnings.filter { $0.lowercased().contains("assumption") })
        }
        if assumptions.isEmpty, !issues.isEmpty {
            assumptions.append("Portion and preparation details were assumed.")
        }

        return .low
    }

    private static func finalizeCalorieRange(
        meal: FoodLogDraft,
        confidence: AIConfidence,
        shouldWiden: Bool
    ) -> FoodCalorieRange {
        let resolved = FoodCalorieRangePolicy.resolve(
            calories: meal.totalCalories,
            confidence: confidence,
            explicitLower: meal.calorieRangeLower,
            explicitUpper: meal.calorieRangeUpper
        )

        if shouldWiden {
            return FoodCalorieRangePolicy.widenForUncertainty(
                calories: meal.totalCalories,
                confidence: confidence,
                lower: resolved.lower,
                upper: resolved.upper,
                upwardBias: confidence == .low ? 60 : 30
            )
        }

        if !FoodCalorieRangePolicy.isWideEnough(
            calories: meal.totalCalories,
            lower: resolved.lower,
            upper: resolved.upper,
            confidence: confidence
        ) {
            return FoodCalorieRangePolicy.derive(calories: meal.totalCalories, confidence: confidence)
        }

        return resolved
    }

    // MARK: - Rule 5

    private static func applyClarificationPolicy(
        requiresClarification: Bool,
        confidence: AIConfidence,
        uncertaintyReasons: [String],
        suggestedClarifications: inout [String]
    ) -> Bool {
        let needsClarification = requiresClarification
            || confidence == .low
            || uncertaintyReasons.contains { reason in
                let lower = reason.lowercased()
                return lower.contains("portion")
                    || lower.contains("sauce")
                    || lower.contains("oil")
                    || lower.contains("unclear")
                    || lower.contains("ambiguous")
            }

        if needsClarification, suggestedClarifications.isEmpty {
            if let reason = uncertaintyReasons.first {
                suggestedClarifications.append("Can you clarify \(reason.lowercased())?")
            } else {
                suggestedClarifications.append("Can you clarify portion size or hidden sauce/oil?")
            }
        }

        return needsClarification
    }

    // MARK: - Existing rules

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

    private static func validateCompositeMixedMealFloor(
        _ meal: FoodLogDraft,
        prompt: String
    ) -> String? {
        let combined = combinedMealText(meal, prompt: prompt)

        let hasChicken = combined.contains("chicken")
        let hasGrain = grainTerms.contains(where: { combined.contains($0) })
        let hasDressing = dressingTerms.contains(where: { combined.contains($0) })
        let hasDessert = dessertTerms.contains(where: { combined.contains($0) })

        guard hasChicken, hasGrain, hasDressing, hasDessert else { return nil }
        guard meal.totalCalories < 550 else { return nil }
        return "Mixed meal with chicken, grain, dressing, and dessert looks under-estimated."
    }

    private static func validateCollapsedCompoundDish(
        _ meal: FoodLogDraft,
        prompt: String
    ) -> String? {
        let analysis = FoodCompoundDishDetector.analyze(prompt: prompt)
        guard !analysis.matchedDishes.isEmpty, analysis.minRequiredComponents > 1 else {
            return nil
        }
        guard meal.components.count < analysis.minRequiredComponents else {
            return nil
        }
        return "Compound dish appears collapsed into too few components."
    }

    private static func validateNonNegativeMacros(_ component: FoodComponent) -> [String] {
        var issues: [String] = []
        if component.calories < 0 {
            issues.append("\(component.name) has negative calories.")
        }
        if component.protein < 0 {
            issues.append("\(component.name) has negative protein.")
        }
        if component.carbs < 0 {
            issues.append("\(component.name) has negative carbs.")
        }
        if component.fat < 0 {
            issues.append("\(component.name) has negative fat.")
        }
        return issues
    }

    // MARK: - Helpers

    private struct ExplicitPortionHint: Equatable {
        let value: Double
        let unit: String
    }

    private static func preservesExplicitPortion(
        _ component: FoodComponent,
        explicitPortions: [ExplicitPortionHint]
    ) -> Bool {
        guard let quantity = component.quantity, let unit = component.unit?.lowercased() else {
            return true
        }
        return !explicitPortions.contains { hint in
            hint.unit == unit && abs(hint.value - quantity) < 0.01
        }
    }

    private static func explicitPortionHints(in prompt: String) -> [ExplicitPortionHint] {
        var hints: [ExplicitPortionHint] = []
        let patterns = [
            (#"(\d+(?:\.\d+)?)\s*(g|gram|grams)\b"#, "g"),
            (#"(\d+(?:\.\d+)?)\s*(ml|millilitre|milliliter|millilitres|milliliters)\b"#, "ml"),
        ]
        for (pattern, unit) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            for match in regex.matches(in: prompt, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: prompt),
                      let value = Double(prompt[valueRange]) else {
                    continue
                }
                hints.append(ExplicitPortionHint(value: value, unit: unit))
            }
        }
        return hints
    }

    private static func resolvedGramWeight(
        for component: FoodComponent,
        prompt: String,
        explicitPortions: [ExplicitPortionHint]
    ) -> Double? {
        if let quantity = component.quantity, isMassUnit(component.unit) {
            return quantity
        }
        let combined = componentSearchText(component, prompt: prompt)
        if let hint = explicitPortions.first(where: { $0.unit == "g" && combined.contains("chicken") }) {
            return hint.value
        }
        return nil
    }

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

    private static func combinedMealText(_ meal: FoodLogDraft, prompt: String) -> String {
        "\(prompt) \(meal.displayName.lowercased()) " +
            meal.components.map { componentSearchText($0, prompt: prompt) }.joined(separator: " ")
    }

    private static func hasSmallPortionHint(_ prompt: String) -> Bool {
        smallPortionTerms.contains(where: { prompt.contains($0) })
    }

    private static func matchesPattern(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func defaultUncertaintyReason(for confidence: AIConfidence) -> String {
        switch confidence {
        case .low:
            return "Portion size or hidden ingredients are unclear."
        case .medium:
            return "Some portion or preparation details were assumed."
        case .high:
            return "Minor preparation details were assumed."
        }
    }

    private static func confidenceLevel(from confidence: AIConfidence) -> ConfidenceLevel {
        confidence.asConfidenceLevel
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result.sorted()
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

    private static func isMassUnit(_ unit: String?) -> Bool {
        guard let unit else { return false }
        switch unit.lowercased() {
        case "g", "gram", "grams", "kg":
            return true
        default:
            return false
        }
    }

    private static func isVolumeUnit(_ unit: String?) -> Bool {
        guard let unit else { return false }
        switch unit.lowercased() {
        case "ml", "millilitre", "milliliter", "millilitres", "milliliters", "l", "liter", "litre":
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
