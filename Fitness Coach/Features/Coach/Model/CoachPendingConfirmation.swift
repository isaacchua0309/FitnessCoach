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
            guard let food = draft.primaryFoodDraft else { return "Food entry" }
            if food.hasUsableNutritionEstimate {
                return "\(food.name) · \(food.calories) kcal · \(AIFoodConfirmationFormatter.macroSummary(for: food))"
            }
            return food.name
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

    var foodDraft: AIFoodConfirmationDraft? {
        if case .food(let draft) = self { return draft }
        return nil
    }
}
