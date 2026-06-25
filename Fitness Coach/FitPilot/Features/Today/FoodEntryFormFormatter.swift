//
//  FoodEntryFormFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Display helpers for food entry UI.
//

import Foundation

enum FoodEntryFormFormatter {

    static func mealTypeLabel(_ mealType: MealType?) -> String {
        switch mealType {
        case .breakfast:
            return "Breakfast"
        case .lunch:
            return "Lunch"
        case .dinner:
            return "Dinner"
        case .snack:
            return "Snack"
        case .unknown, nil:
            return "Unknown"
        }
    }

    static func confidenceLabel(_ confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }

    static func macroLine(protein: Double, carbs: Double, fat: Double) -> String {
        "P \(formatMacro(protein))g / C \(formatMacro(carbs))g / F \(formatMacro(fat))g"
    }

    static func formatMacro(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    static func formatOptionalDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return formatMacro(value)
    }
}
