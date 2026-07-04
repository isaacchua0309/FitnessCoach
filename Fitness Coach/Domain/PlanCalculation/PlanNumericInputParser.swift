//
//  PlanNumericInputParser.swift
//  Fitness Coach
//
//  Forma — Shared decimal input parsing for Edit Plan fields.
//

import Foundation

enum PlanNumericInputIssue: Equatable, Sendable {
    case empty
    case invalidFormat
    case nonPositive
}

enum PlanNumericInputParser {

    static func parsePositiveDecimal(_ text: String) -> Result<Double, PlanNumericInputIssue> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.empty)
        }

        guard isValidDecimalFormat(trimmed) else {
            return .failure(.invalidFormat)
        }

        guard let value = Double(trimmed), value > 0 else {
            return .failure(.nonPositive)
        }

        return .success(value)
    }

    private static func isValidDecimalFormat(_ text: String) -> Bool {
        let pattern = #"^\d+(\.\d+)?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}
