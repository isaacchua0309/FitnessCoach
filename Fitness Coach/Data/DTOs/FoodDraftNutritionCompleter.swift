//
//  FoodDraftNutritionCompleter.swift
//  Fitness Coach
//
//  FitPilot AI — Sanitizes classifier partials; does not invent nutrition client-side.
//

import Foundation

enum FoodDraftNutritionCompleter {

    /// Clears portion fields that were likely confused with macro grams. Never fills missing macros.
    static func sanitizePartial(_ draft: FoodDraft, hintText: String) -> FoodDraft {
        var result = draft
        let normalized = hintText.lowercased()

        if shouldClearPortionConfusedWithProtein(result, hintText: normalized) {
            result.quantity = nil
            result.unit = nil
        }

        if shouldClearPortionConfusedWithCalories(result, hintText: normalized) {
            result.quantity = nil
            result.unit = nil
        }

        return result
    }

    /// Applies user-stated nutrition from the classifier onto an AI estimate. Portion comes from AI only.
    static func mergeExplicit(
        _ explicit: FoodDraft,
        into estimate: FoodDraft,
        hintText: String
    ) -> FoodDraft {
        let sanitized = sanitizePartial(explicit, hintText: hintText)
        var merged = estimate
        if sanitized.calories > 0 { merged.calories = sanitized.calories }
        if sanitized.protein > 0 { merged.protein = sanitized.protein }
        if sanitized.carbs > 0 { merged.carbs = sanitized.carbs }
        if sanitized.fat > 0 { merged.fat = sanitized.fat }
        if !sanitized.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.name = sanitized.name
        }
        if let mealType = sanitized.mealType { merged.mealType = mealType }
        return merged
    }

    // MARK: - Private

    private static func macroTotal(_ draft: FoodDraft) -> Double {
        draft.protein + draft.carbs + draft.fat
    }

    private static func shouldClearPortionConfusedWithProtein(
        _ draft: FoodDraft,
        hintText: String
    ) -> Bool {
        guard draft.protein > 0,
              let quantity = draft.quantity,
              isMassUnit(draft.unit),
              abs(quantity - draft.protein) < 0.01
        else { return false }

        return hintText.contains("protein")
            || hintText.contains("pro ")
            || matchesMacroPattern(hintText, value: quantity, keywords: ["protein", "pro"])
    }

    private static func shouldClearPortionConfusedWithCalories(
        _ draft: FoodDraft,
        hintText: String
    ) -> Bool {
        guard draft.calories > 0,
              macroTotal(draft) == 0,
              let quantity = draft.quantity,
              isMassUnit(draft.unit),
              abs(quantity - Double(draft.calories)) < 0.01
        else { return false }

        return hintText.contains("calorie")
            || hintText.contains("kcal")
            || matchesMacroPattern(hintText, value: quantity, keywords: ["calories", "calorie", "kcal", "cal"])
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

    private static func matchesMacroPattern(
        _ text: String,
        value: Double,
        keywords: [String]
    ) -> Bool {
        let valueText = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
        for keyword in keywords {
            if text.range(
                of: #"\#(valueText)\s*(g\s+)?\#(keyword)"#,
                options: .regularExpression
            ) != nil {
                return true
            }
            if text.range(
                of: #"\#(keyword)\s*\#(valueText)"#,
                options: .regularExpression
            ) != nil {
                return true
            }
        }
        return false
    }
}
