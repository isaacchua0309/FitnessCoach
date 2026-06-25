//
//  InputNormalizer.swift
//  Fitness Coach
//
//  FitPilot AI — deterministic text normalization for Coach routing.
//

import Foundation

struct NormalizedInput: Equatable, Sendable {
    var originalText: String
    var trimmedText: String
    var normalizedText: String
    var tokens: [String]

    var meaningfulTokenCount: Int {
        tokens.filter { token in
            token.rangeOfCharacter(from: .alphanumerics) != nil
        }.count
    }

    var isPunctuationOnly: Bool {
        !trimmedText.isEmpty
            && trimmedText.rangeOfCharacter(from: .alphanumerics) == nil
    }
}

enum InputNormalizer {
    static func normalize(_ text: String) -> NormalizedInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = CommandParserUtilities.normalized(trimmed)
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        return NormalizedInput(
            originalText: text,
            trimmedText: trimmed,
            normalizedText: normalized,
            tokens: tokens
        )
    }
}
