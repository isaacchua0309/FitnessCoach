//
//  PlanDisplayFormatter.swift
//  Fitness Coach
//
//  Forma — Shared display formatting for plan rationale and calculation details.
//

import Foundation

enum PlanDisplayFormatter {

    static func formatKcal(_ value: Int) -> String {
        "\(formatGroupedInteger(value)) kcal"
    }

    static func formatKcalPerDay(_ value: Int) -> String {
        "\(formatKcal(value))/day"
    }

    static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : String(format: "%.0f g", value)
    }

    /// Highlight row protein value (e.g. `180g` with rounded fractional grams).
    static func formatGramsCompactHighlight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : "\(Int(value.rounded()))g"
    }

    static func formatMl(_ value: Int) -> String {
        "\(formatGroupedInteger(value)) ml"
    }

    static func formatMlPerDay(_ value: Int) -> String {
        "\(formatGroupedInteger(value))ml/day"
    }

    static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }

    static func formatCm(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) cm"
            : String(format: "%.1f cm", value)
    }

    static func formatMultiplier(_ value: Double) -> String {
        String(format: "×%.2f", value)
    }

    static func formatGroupedInteger(_ value: Int) -> String {
        decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
