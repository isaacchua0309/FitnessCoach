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
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }

    static func sourceLabel(_ source: FoodEntrySource) -> String {
        switch source {
        case .manual:
            return "Manual"
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

    static func macroSummary(for draft: FoodDraft) -> String {
        FoodEntryFormFormatter.macroLine(
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat
        )
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
            return "This is a low-confidence estimate. Please review and edit before logging."
        }
    }
}
