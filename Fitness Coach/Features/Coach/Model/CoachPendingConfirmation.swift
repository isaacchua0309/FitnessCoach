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
            let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)
            var lines: [String] = [presentation.mealName, presentation.estimatedCaloriesLine]
            if let rangeLine = presentation.likelyRangeLine {
                lines.append(rangeLine)
            }
            lines.append(presentation.confidenceLine)
            if let mainUncertainty = presentation.mainUncertaintyLine {
                lines.append(mainUncertainty)
            }
            if let lowWarning = presentation.lowConfidenceWarning {
                lines.append(lowWarning)
            }
            lines.append(contentsOf: presentation.assumptionLines)
            if let sanityWarning = presentation.sanityWarning, !sanityWarning.isEmpty {
                lines.append(sanityWarning)
            }
            if let sourceLine = presentation.sourceLine {
                lines.append(sourceLine)
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
            return CoachPendingFoodEstimatePresentationBuilder.compactDetailLine(for: draft)
                ?? draft.primaryMealDraft.displayName
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
