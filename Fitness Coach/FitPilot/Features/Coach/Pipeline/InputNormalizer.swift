//
//  InputNormalizer.swift
//  Fitness Coach
//
//  FitPilot AI — deterministic text normalization for Coach routing.
//

import Foundation

struct NormalizedCoachInput: Equatable, Sendable {
    var originalText: String
    var normalizedText: String
    var routingText: String
    var tokens: [String]

    var isEmpty: Bool {
        normalizedText.isEmpty
    }

    var meaningfulTokenCount: Int {
        tokens.filter { token in
            token.rangeOfCharacter(from: .alphanumerics) != nil
        }.count
    }

    var isPunctuationOnly: Bool {
        !normalizedText.isEmpty
            && normalizedText.rangeOfCharacter(from: .alphanumerics) == nil
    }

    var isMeaninglessSingleToken: Bool {
        guard meaningfulTokenCount == 1, let token = tokens.first else { return false }
        let meaningless = ["ok", "okay", "k", "??", "???", "hmm", "hm", "uh", "um"]
        return meaningless.contains(token)
    }
}

enum InputNormalizer {
    static func normalize(_ text: String) -> NormalizedCoachInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = CommandParserUtilities.normalized(trimmed)
        let routingText = stripPunctuationForRouting(normalized)
        let tokens = routingText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        return NormalizedCoachInput(
            originalText: text,
            normalizedText: normalized,
            routingText: routingText,
            tokens: tokens
        )
    }

    private static func stripPunctuationForRouting(_ text: String) -> String {
        text.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
