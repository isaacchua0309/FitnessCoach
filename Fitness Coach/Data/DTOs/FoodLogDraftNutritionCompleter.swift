//
//  FoodLogDraftNutritionCompleter.swift
//  Fitness Coach
//
//  FitPilot AI — Sanitizes multi-component meal drafts from AI responses.
//

import Foundation

enum FoodLogDraftNutritionCompleter {

    static let lowConfidenceReviewWarning = FoodCompoundDishDetector.lowConfidenceReviewMessage

    static func sanitize(_ meal: FoodLogDraft, hintText: String) -> FoodLogDraft {
        var result = meal
        result.components = meal.components.map {
            clampComponentMacros(sanitizeComponent($0, hintText: hintText))
        }
        result.displayName = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: result.displayName,
            components: result.components
        )
        result = clearMixedMealPortionFields(result)
        result = appendReviewWarnings(result, hintText: hintText)
        result = FoodCalorieRangeResolver.fillMissingRanges(result)
        return FoodLogDraftMapper.reconcileTotals(result)
    }

    static func mergeExplicit(
        _ explicit: FoodDraft,
        into meal: FoodLogDraft,
        hintText: String
    ) -> FoodLogDraft {
        let sanitizedExplicit = FoodDraftNutritionCompleter.sanitizePartial(explicit, hintText: hintText)
        var merged = meal

        if !sanitizedExplicit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.displayName = sanitizedExplicit.name
        }
        if let mealType = sanitizedExplicit.mealType {
            merged.mealType = mealType
        }

        if meal.components.count == 1, sanitizedExplicit.hasCompleteNutritionEstimate {
            var component = meal.components[0]
            if sanitizedExplicit.calories > 0 { component.calories = sanitizedExplicit.calories }
            if sanitizedExplicit.protein > 0 { component.protein = sanitizedExplicit.protein }
            if sanitizedExplicit.carbs > 0 { component.carbs = sanitizedExplicit.carbs }
            if sanitizedExplicit.fat > 0 { component.fat = sanitizedExplicit.fat }
            merged.components[0] = component
        }

        return sanitize(merged, hintText: hintText)
    }

    private static func sanitizeComponent(_ component: FoodComponent, hintText: String) -> FoodComponent {
        let draft = FoodDraft(
            mealType: nil,
            name: component.name,
            quantity: component.quantity,
            unit: component.unit,
            calories: component.calories,
            protein: component.protein,
            carbs: component.carbs,
            fat: component.fat,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: component.confidence,
            imageUrl: nil,
            notes: component.sourceText
        )
        let sanitized = FoodDraftNutritionCompleter.sanitizePartial(draft, hintText: hintText)
        var result = component
        result.quantity = sanitized.quantity
        result.unit = sanitized.unit
        return result
    }

    /// Mixed meals must not borrow the first ingredient's grams as the meal amount.
    private static func clearMixedMealPortionFields(_ meal: FoodLogDraft) -> FoodLogDraft {
        guard meal.isMultiComponent else { return meal }
        return meal
    }

    private static func clampComponentMacros(_ component: FoodComponent) -> FoodComponent {
        var result = component
        result.calories = max(0, component.calories)
        result.protein = max(0, component.protein)
        result.carbs = max(0, component.carbs)
        result.fat = max(0, component.fat)
        return result
    }

    private static func appendReviewWarnings(_ meal: FoodLogDraft, hintText: String) -> FoodLogDraft {
        var result = meal
        var warnings = Set(result.warnings)
        let analysis = FoodCompoundDishDetector.analyze(prompt: hintText)

        if analysis.isAmbiguousServing || result.confidence == .low {
            warnings.insert(lowConfidenceReviewWarning)
        }

        if !analysis.matchedDishes.isEmpty,
           result.components.count < analysis.minRequiredComponents {
            warnings.insert(NutritionSanityResult.collapsedCompoundDishUserMessage)
        }

        result.warnings = Array(warnings).sorted()
        return result
    }
}
