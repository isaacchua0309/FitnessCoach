//
//  FoodEntryFormFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Display helpers for food entry UI.
//

import Foundation

enum FoodEntryFormFormatter {

    /// Picker / form label. Unknown is shown only in edit UI, not on Today meal rows.
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
            return "Not set"
        }
    }

    /// Meal type for read-only lists. Omits unknown / unset values.
    static func displayMealTypeLabel(_ mealType: MealType?) -> String? {
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
            return nil
        }
    }

    /// Sentence-style title for logged food names (e.g. "chicken breast" → "Chicken breast").
    static func displayFoodName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return name }
        guard trimmed == trimmed.lowercased() else { return trimmed }
        let first = trimmed.prefix(1).uppercased()
        let rest = trimmed.dropFirst().lowercased()
        return first + rest
    }

    /// Subtitle for Today meal rows — readable macros, optional meal type, never "Unknown".
    static func timelineSubtitle(
        mealType: MealType?,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> String? {
        let parts = [displayMealTypeLabel(mealType), timelineMacroSummary(protein: protein, carbs: carbs, fat: fat)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    static func timelineMacroSummary(protein: Double, carbs: Double, fat: Double) -> String? {
        let hasProtein = protein > 0
        let hasCarbs = carbs > 0
        let hasFat = fat > 0
        guard hasProtein || hasCarbs || hasFat else { return nil }

        if hasCarbs || hasFat {
            return [
                "\(formatMacro(protein))g protein",
                "\(formatMacro(carbs))g carbs",
                "\(formatMacro(fat))g fat"
            ].joined(separator: " · ")
        }

        return "\(formatMacro(protein))g protein"
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

    /// Logged body weight in kg (two decimal places).
    static func formatWeight(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func formatOptionalDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return formatMacro(value)
    }
}
