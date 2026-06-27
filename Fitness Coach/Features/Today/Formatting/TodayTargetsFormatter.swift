//
//  TodayTargetsFormatter.swift
//  Fitness Coach
//
//  Forma — Display formatting for Today's Targets progress rows.
//

import Foundation

enum TodayTargetsFormatter {

    /// Example: `31 / 180 g`
    static func macroProgress(consumed: Double, target: Double) -> String {
        "\(formatAmount(consumed)) / \(formatAmount(target)) g"
    }

    /// Example: `500 / 3150 ml`
    static func waterProgress(consumedMl: Int, targetMl: Int) -> String {
        "\(consumedMl) / \(targetMl) ml"
    }

    private static func formatAmount(_ value: Double) -> String {
        FoodEntryFormFormatter.formatMacro(value)
    }
}
