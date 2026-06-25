//
//  CommandParserUtilities.swift
//  Fitness Coach
//
//  FitPilot AI — Small deterministic helpers for local command parsing.
//
//  These helpers only inspect strings. They do not call services, touch
//  SwiftData, or invoke AI.
//

import Foundation

enum CommandParserUtilities {

    /// Trims surrounding whitespace, lowercases, and collapses internal runs of
    /// whitespace into single spaces.
    static func normalized(_ text: String) -> String {
        let lowered = text.lowercased()
        let components = lowered.split(whereSeparator: { $0.isWhitespace })
        return components.joined(separator: " ")
    }

    /// All decimal/integer numbers found in the text, in order of appearance.
    /// A leading minus sign is captured so negative values can be validated.
    static func allDoubles(in text: String) -> [Double] {
        let pattern = "-?[0-9]+(?:\\.[0-9]+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return Double(text[r])
        }
    }

    /// The first decimal/integer number found in the text.
    static func firstDouble(in text: String) -> Double? {
        allDoubles(in: text).first
    }

    /// The first whole-number value found in the text.
    static func firstInt(in text: String) -> Int? {
        let pattern = "-?[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let r = Range(match.range, in: text)
        else { return nil }
        return Int(text[r])
    }

    /// Extracts an explicit water amount with a unit (ml or litres) and converts
    /// to millilitres. Returns nil when no explicit unit is present.
    static func extractWaterAmountMl(from text: String) -> Int? {
        let mlPattern = "(-?[0-9]+(?:\\.[0-9]+)?)\\s*(?:ml|millilitres?|milliliters?)\\b"
        if let value = firstQuantity(in: text, pattern: mlPattern) {
            return Int(value.rounded())
        }

        let litrePattern = "(-?[0-9]+(?:\\.[0-9]+)?)\\s*(?:l|litres?|liters?)\\b"
        if let value = firstQuantity(in: text, pattern: litrePattern) {
            return Int((value * 1000).rounded())
        }

        return nil
    }

    /// Finds a number that directly precedes a keyword, optionally separated by a
    /// "g" unit suffix. Example: "72g protein" or "78 protein" -> the number.
    static func numberPreceding(keyword: String, in text: String) -> Double? {
        let escaped = NSRegularExpression.escapedPattern(for: keyword)
        let pattern = "(-?[0-9]+(?:\\.[0-9]+)?)\\s*g?\\s*\(escaped)\\b"
        return firstQuantity(in: text, pattern: pattern)
    }

    /// Finds a number that follows any of the given keywords. Example:
    /// "calories 413" or "kcal 360" -> the number.
    static func numberFollowing(keywords: [String], in text: String) -> Double? {
        for keyword in keywords {
            let escaped = NSRegularExpression.escapedPattern(for: keyword)
            let pattern = "\(escaped)\\s*(-?[0-9]+(?:\\.[0-9]+)?)"
            if let value = firstQuantity(in: text, pattern: pattern) {
                return value
            }
        }
        return nil
    }

    /// Returns true when the text contains any of the given whole words.
    static func containsWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    // MARK: Private

    /// Returns the first capture-group-1 numeric value for the given pattern.
    private static func firstQuantity(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges >= 2,
            let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[r])
    }
}
