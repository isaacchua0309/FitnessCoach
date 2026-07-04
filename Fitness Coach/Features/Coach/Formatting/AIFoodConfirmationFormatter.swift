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

    static func totalCalories(for meals: [FoodLogDraft]) -> Int {
        meals.reduce(0) { $0 + $1.totalCalories }
    }

    static func totalCalories(for drafts: [FoodDraft]) -> Int {
        drafts.reduce(0) { $0 + $1.calories }
    }

    static func confirmationWarning(confidence: AIConfidence) -> String {
        switch confidence {
        case .high:
            return FormaProductCopy.Coach.pendingReviewBeforeLogging
        case .medium:
            return "Medium-confidence estimate — review before logging."
        case .low:
            return FormaProductCopy.Coach.pendingLowConfidenceWarning
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
        return FormaProductCopy.Coach.pendingLowConfidenceWarning
    }

    static func assumptionLines(for meal: FoodLogDraft) -> [String] {
        meal.components.compactMap { component in
            let assumptions = component.sourceText?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !assumptions.isEmpty else { return nil }
            return "\(component.name): \(assumptions)"
        }
    }
}
