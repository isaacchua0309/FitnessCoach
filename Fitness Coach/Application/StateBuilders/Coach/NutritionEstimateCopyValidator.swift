//
//  NutritionEstimateCopyValidator.swift
//  Fitness Coach
//
//  Forma — Enforces product copy limits and banned phrases for nutrition cards.
//

import Foundation

enum NutritionEstimateCopyValidator {

    static let summaryMaxLength = 120
    static let tipMaxLength = 140
    static let caveatMaxLength = 90
    static let maxCaveats = 2

    private static let bannedPhrases = [
        "short answer",
        "it depends",
        "in general",
        "if you're watching calories",
        "if you are watching calories",
        "a typical",
    ]

    static func sanitize(_ response: NutritionEstimateResponse) -> NutritionEstimateResponse {
        var copy = response
        copy.coachSummary = sanitizeLine(response.coachSummary, maxLength: summaryMaxLength)
        copy.coachTip = sanitizeLine(response.coachTip, maxLength: tipMaxLength)
        copy.caveats = response.caveats
            .map { sanitizeLine($0, maxLength: caveatMaxLength) ?? "" }
            .filter { !$0.isEmpty }
            .prefix(maxCaveats)
            .map { $0 }
        return copy
    }

    static func sanitizeComparison(_ response: NutritionComparisonResponse) -> NutritionComparisonResponse {
        var copy = response
        copy.coachPick = sanitizeLine(response.coachPick, maxLength: tipMaxLength)
        return copy
    }

    static func sanitizeLine(_ text: String?, maxLength: Int) -> String? {
        guard var value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        for phrase in bannedPhrases {
            value = value.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }
        value = value.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return nil }
        if value.count > maxLength {
            let end = value.index(value.startIndex, offsetBy: maxLength)
            value = String(value[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.hasSuffix(".") && !value.hasSuffix("…") {
                value += "…"
            }
        }
        return value
    }

    static func compactFallbackLines(from text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
        return lines.joined(separator: "\n")
    }
}
