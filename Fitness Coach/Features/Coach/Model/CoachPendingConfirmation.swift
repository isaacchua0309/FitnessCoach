//
//  CoachPendingConfirmation.swift
//  Fitness Coach
//
//  FitPilot AI — Unified pending confirmation state for Coach mutations.
//

import Foundation

enum CoachPendingConfirmation: Equatable {
    case food(AIFoodConfirmationDraft)
    case water(WaterDraft, assistantMessage: String?)
    case weight(WeightDraft, assistantMessage: String?)
    case edit(AICommandAction, originalText: String, assistantMessage: String?)
    case delete(AICommandAction, originalText: String, assistantMessage: String?)
    case undo(AICommandAction, originalText: String, assistantMessage: String?)

    var kindLabel: String {
        switch self {
        case .food: return "Food"
        case .water: return "Water"
        case .weight: return "Weight"
        case .edit: return "Edit"
        case .delete: return "Delete"
        case .undo: return "Undo"
        }
    }

    var summaryLine: String {
        switch self {
        case .food(let draft):
            let meal = draft.primaryMealDraft
            var lines: [String] = []
            if meal.hasUsableNutritionEstimate {
                lines.append(
                    "\(meal.displayName) · \(meal.totalCalories) kcal · \(AIFoodConfirmationFormatter.macroSummary(for: meal))"
                )
            } else {
                lines.append(meal.displayName)
            }
            lines.append(AIFoodConfirmationFormatter.confidenceLabel(draft.confidence))
            let assumptions = AIFoodConfirmationFormatter.assumptionLines(for: meal)
            if !assumptions.isEmpty {
                lines.append(contentsOf: assumptions)
            }
            if let sanityWarning = draft.sanityWarning, !sanityWarning.isEmpty {
                lines.append(sanityWarning)
            }
            return lines.joined(separator: "\n")
        case .water(let draft, _):
            return "\(draft.amountMl) ml water"
        case .weight(let draft, _):
            return String(format: "%.2f kg", draft.weightKg)
        case .edit(_, _, let message), .delete(_, _, let message), .undo(_, _, let message):
            return message ?? "Review this change before applying it."
        }
    }

    var supportsEdit: Bool {
        if case .food = self { return true }
        return false
    }

    var supportsPhotoRetry: Bool {
        guard case .food(let draft) = self else { return false }
        return draft.relatedPhotoUserMessageID != nil && draft.confidence == .low
    }

    var relatedPhotoUserMessageID: UUID? {
        foodDraft?.relatedPhotoUserMessageID
    }

    var foodDraft: AIFoodConfirmationDraft? {
        if case .food(let draft) = self { return draft }
        return nil
    }
}
