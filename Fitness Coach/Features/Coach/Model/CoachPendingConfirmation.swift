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
                    "\(meal.displayName) · \(AIFoodConfirmationFormatter.caloriesDisplay(for: meal)) · \(AIFoodConfirmationFormatter.macroSummary(for: meal))"
                )
            } else {
                lines.append(meal.displayName)
            }
            if let sourceLine = AIFoodConfirmationFormatter.pendingSourceLabel(
                sourceAttribution: draft.sourceAttribution,
                foodSource: meal.source
            ) {
                lines.append(sourceLine)
            }
            lines.append(AIFoodConfirmationFormatter.confidenceLabel(draft.confidence))
            if let reviewWarning = AIFoodConfirmationFormatter.pendingReviewWarning(
                confidence: draft.confidence
            ) {
                lines.append(reviewWarning)
            }
            let assumptions = AIFoodConfirmationFormatter.explicitAssumptionSection(for: meal)
            if !assumptions.isEmpty {
                lines.append("Assumptions:")
                lines.append(contentsOf: assumptions)
            }
            if let sanityWarning = draft.sanityWarning, !sanityWarning.isEmpty {
                lines.append(sanityWarning)
            }
            if draft.requiresEditBeforeConfirm {
                lines.append(FoodEstimateTrustPolicy.editBeforeLoggingMessage)
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

    var isConfirmBlocked: Bool {
        guard case .food(let draft) = self else { return false }
        return draft.requiresEditBeforeConfirm
    }

    var confirmBlockedReason: String? {
        guard case .food(let draft) = self, draft.requiresEditBeforeConfirm else { return nil }
        return FoodEstimateTrustPolicy.editBeforeLoggingMessage
    }

    var relatedPhotoUserMessageID: UUID? {
        foodDraft?.relatedPhotoUserMessageID
    }

    var foodDraft: AIFoodConfirmationDraft? {
        if case .food(let draft) = self { return draft }
        return nil
    }

    /// Short headline for the compact pending bar while the composer is focused.
    var compactTitle: String {
        switch self {
        case .food:
            return FormaProductCopy.Coach.foodEstimatePending
        case .water, .weight, .edit, .delete, .undo:
            return FormaProductCopy.Coach.reviewEstimate
        }
    }

    /// Optional secondary line for the compact pending bar (e.g. calories).
    var compactDetailLine: String? {
        switch self {
        case .food(let draft):
            let meal = draft.primaryMealDraft
            if meal.hasUsableNutritionEstimate {
                return AIFoodConfirmationFormatter.compactCaloriesDisplay(for: meal)
            }
            let name = meal.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .water(let draft, _):
            return "\(draft.amountMl) ml"
        case .weight(let draft, _):
            return String(format: "%.1f kg", draft.weightKg)
        case .edit, .delete, .undo:
            let firstLine = summaryLine
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return firstLine?.isEmpty == false ? firstLine : nil
        }
    }
}
