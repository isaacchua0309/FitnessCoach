//
//  AIFoodConfirmationFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Display helpers for AI food confirmation UI.
//

import Foundation

enum AIFoodConfirmationFormatter {

    static func confidenceLabel(_ confidence: AIConfidence) -> String {
        switch confidence {
        case .high:
            return FoodEntryFormFormatter.confidenceLabel(.high)
        case .medium:
            return FoodEntryFormFormatter.confidenceLabel(.medium)
        case .low:
            return FoodEntryFormFormatter.confidenceLabel(.low)
        }
    }

    static func sourceLabel(_ source: FoodEntrySource) -> String {
        switch source {
        case .manual:
            return "Custom food"
        case .aiTextEstimate:
            return "AI text estimate"
        case .aiPhotoEstimate:
            return "AI photo estimate"
        case .nutritionLabel:
            return "Nutrition label"
        case .savedMeal:
            return "Saved meal"
        case .corrected:
            return "Corrected estimate"
        }
    }

    static func macroSummary(for meal: FoodLogDraft) -> String {
        FoodEntryFormFormatter.macroLine(
            protein: meal.totalProtein,
            carbs: meal.totalCarbs,
            fat: meal.totalFat
        )
    }

    static func macroSummary(for draft: FoodDraft) -> String {
        macroSummary(for: FoodLogDraftMapper.fromLegacyDraft(draft))
    }

    static func caloriesDisplay(for meal: FoodLogDraft) -> String {
        if let range = FoodCalorieRangeResolver.resolvedRange(for: meal) {
            if range.lower == range.upper {
                return "\(PlanDisplayFormatter.formatGroupedInteger(range.lower)) kcal"
            }
            return "\(PlanDisplayFormatter.formatGroupedInteger(range.lower))–\(PlanDisplayFormatter.formatGroupedInteger(range.upper)) kcal"
        }
        if meal.totalCalories > 0 {
            return "~\(PlanDisplayFormatter.formatGroupedInteger(meal.totalCalories)) kcal"
        }
        return "Estimated kcal"
    }

    static func compactCaloriesDisplay(for meal: FoodLogDraft) -> String {
        if let range = FoodCalorieRangeResolver.resolvedRange(for: meal) {
            if range.lower == range.upper {
                return "\(range.lower) kcal"
            }
            return "\(range.lower)–\(range.upper) kcal"
        }
        if meal.totalCalories > 0 {
            return "~\(meal.totalCalories) kcal"
        }
        return "Estimated kcal"
    }

    static func totalCalories(for meals: [FoodLogDraft]) -> Int {
        meals.reduce(0) { $0 + $1.totalCalories }
    }

    static func totalCalories(for drafts: [FoodDraft]) -> Int {
        drafts.reduce(0) { $0 + $1.calories }
    }

    static func confirmationWarning(confidence: AIConfidence) -> String {
        switch confidence {
        case .high:
            return "Please review this estimate before logging."
        case .medium:
            return "This is a medium-confidence estimate. Please review before logging."
        case .low:
            return FormaProductCopy.Coach.pendingReviewBeforeLogging
        }
    }

    static func pendingSourceLabel(
        sourceAttribution: CoachTimelineEventSourceAttribution?,
        foodSource: FoodEntrySource
    ) -> String? {
        if sourceAttribution == .mealImage || foodSource == .aiPhotoEstimate {
            return FormaProductCopy.Coach.pendingSourceMealPhoto
        }
        if sourceAttribution == .commonFoodReference {
            return FormaProductCopy.Coach.pendingSourceCommonFood
        }
        return nil
    }

    static func pendingReviewWarning(confidence: AIConfidence) -> String? {
        guard confidence == .low else { return nil }
        return FormaProductCopy.Coach.pendingReviewBeforeLogging
    }

    static func assumptionLines(for meal: FoodLogDraft) -> [String] {
        var lines: [String] = []

        let mealAssumptions = meal.assumptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !mealAssumptions.isEmpty {
            lines.append(contentsOf: mealAssumptions.map { "Assumption: \($0)" })
        }

        let componentAssumptions = meal.components.compactMap { component -> String? in
            let assumptions = component.sourceText?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !assumptions.isEmpty else { return nil }
            return "\(component.name): \(assumptions)"
        }
        lines.append(contentsOf: componentAssumptions)
        return lines
    }

    static func explicitAssumptionSection(for meal: FoodLogDraft) -> [String] {
        assumptionLines(for: meal)
    }
}
