//
//  CommandKeywordFuzzyMatcher.swift
//  Fitness Coach
//
//  FitPilot AI — conservative 1-edit fuzzy matching for local command keywords only.
//

import Foundation

enum CommandKeywordFuzzyMatcher {
    private static let keywords = [
        "water", "weight", "weigh", "status", "summary",
        "undo", "delete", "remove"
    ]

    /// Applies at most one 1-edit correction per token against the allowed keyword list.
    static func correctKeywords(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let pattern = "[A-Za-z]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var output = text
        let matches = regex.matches(in: text, range: nsRange).reversed()

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let token = String(text[range]).lowercased()
            guard let correction = correctedKeyword(for: token) else { continue }
            output.replaceSubrange(range, with: correction)
        }

        return output
    }

    private static func correctedKeyword(for token: String) -> String? {
        guard token.count >= 3 else { return nil }
        if keywords.contains(token) { return nil }

        var bestMatch: String?
        for keyword in keywords {
            guard abs(keyword.count - token.count) <= 1 else { continue }
            guard keyword.count <= 8 else { continue }
            guard editDistance(token, keyword) == 1 else { continue }
            if bestMatch != nil { return nil }
            bestMatch = keyword
        }
        return bestMatch
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)

        for (i, leftChar) in left.enumerated() {
            var current = [i + 1]
            for (j, rightChar) in right.enumerated() {
                let insertions = previous[j + 1] + 1
                let deletions = current[j] + 1
                let substitutions = previous[j] + (leftChar == rightChar ? 0 : 1)
                var best = min(insertions, deletions, substitutions)

                if i > 0, j > 0, leftChar == right[j - 1], left[i - 1] == rightChar {
                    best = min(best, previous[j - 1])
                }

                current.append(best)
            }
            previous = current
        }

        return previous[right.count]
    }
}
