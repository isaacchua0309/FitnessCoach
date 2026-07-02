//
//  FoodComponentDisplayFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only component lines for multi-component meal UI.
//

import Foundation

enum FoodComponentDisplayFormatter {

    /// e.g. "Chicken breast — 150g cooked"
    static func portionLine(_ component: FoodComponent) -> String {
        let name = displayName(component.name)
        let portion = portionDescription(for: component)
        guard !portion.isEmpty else { return name }
        return "\(name) — \(portion)"
    }

    /// Chat copy: portion plus per-component calories when available.
    static func summaryLine(_ component: FoodComponent) -> String {
        let line = portionLine(component)
        guard component.calories > 0 else { return "• \(line)" }
        return "• \(line) · \(component.calories) kcal"
    }

    static func displayName(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return raw }

        let lowered = cleaned.lowercased()
        for prefix in leadingDescriptors {
            if lowered.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        for word in inlineDescriptors {
            cleaned = cleaned.replacingOccurrences(
                of: word,
                with: "",
                options: [.caseInsensitive, .regularExpression]
            )
        }

        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return FoodEntryFormFormatter.displayFoodName(raw)
        }
        return FoodEntryFormFormatter.displayFoodName(cleaned)
    }

    static func portionDescription(for component: FoodComponent) -> String {
        var parts: [String] = []

        if let quantity = component.quantity {
            let unit = component.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if unit.isEmpty {
                if let formatted = FoodEntryFormFormatter.formatOptionalDouble(quantity) {
                    parts.append(formatted)
                } else {
                    parts.append(String(quantity))
                }
            } else if unit == "g" || unit == "ml" {
                let amount = FoodEntryFormFormatter.formatOptionalDouble(quantity)
                    ?? String(format: "%.0f", quantity)
                parts.append("\(amount)\(unit)")
            } else {
                let amount = FoodEntryFormFormatter.formatOptionalDouble(quantity)
                    ?? String(quantity)
                parts.append("\(amount) \(unit)")
            }
        }

        if let preparation = component.preparationState?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !preparation.isEmpty {
            let nameLower = component.name.lowercased()
            if !nameLower.contains(preparation.lowercased()) {
                parts.append(preparation)
            }
        }

        return parts.joined(separator: " ")
    }

    private static let leadingDescriptors = [
        "cooked ",
        "raw ",
        "grilled ",
        "baked ",
        "fried ",
        "roasted ",
        "steamed ",
        "boiled ",
        "fresh ",
        "creamy ",
        "homemade "
    ]

    private static let inlineDescriptors = [
        "\\bskinless\\b",
        "\\bboneless\\b"
    ]
}
