//
//  FoodListedIngredientCounter.swift
//  Fitness Coach
//
//  FitPilot AI — Counts listed ingredients in Coach food logging prompts.
//

import Foundation

enum FoodListedIngredientCounter {

    static func count(in text: String) -> Int {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var count = 0
        for line in lines {
            if line.range(of: #"^[-*•]\s+"#, options: .regularExpression) != nil
                || line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) != nil {
                count += 1
                continue
            }
            if line.range(
                of: #"\d+\s*[-–]\s*\d+\s*(?:g|gram|grams)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                count += 1
                continue
            }
            if line.range(
                of: #"\d+(?:\.\d+)?\s*(?:g|gram|grams|kg|ml|tbsp|tablespoon|cup|cups)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                count += 1
            }
        }

        if count >= 2 {
            return count
        }

        let normalized = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let clauses = splitClauses(normalized)
            .filter { !$0.isEmpty }

        let foodClauseCount = clauses.filter(isFoodClause).count
        if foodClauseCount >= 2 {
            return foodClauseCount
        }

        let commaSeparated = text
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.rangeOfCharacter(from: .decimalDigits) != nil && $0.rangeOfCharacter(from: .letters) != nil }

        return commaSeparated.count >= 2 ? commaSeparated.count : max(count, 0)
    }

    private static func splitClauses(_ text: String) -> [String] {
        let andSeparated = text
            .replacingOccurrences(of: " and ", with: ",", options: .caseInsensitive)
        return andSeparated
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func isFoodClause(_ part: String) -> Bool {
        if part.range(
            of: #"\d+\s*[-–]\s*\d+\s*(?:g|gram|grams)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
        if part.range(
            of: #"\d+(?:\.\d+)?\s*(?:g|gram|grams|kg|ml|tbsp|tablespoon|cup|cups)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
        if part.range(
            of: #"\b(one|two|a|an)\s+(bowl|plate|cup|serving)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
        if part.range(
            of: #"\b(chicken|rice|beef|fish|egg|sauce|dressing|salad|pasta|barley)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }
        return false
    }
}
