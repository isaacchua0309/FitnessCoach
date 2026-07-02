//
//  CoachInputSafety.swift
//  Fitness Coach
//
//  FitPilot AI — client-side input limits and Unicode-safe routing normalization.
//

import Foundation

enum CoachInputValidation: Equatable, Sendable {
    case valid
    case empty
    case tooLong(maxCharacters: Int)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

enum CoachInputSafety {
    /// Matches the Firebase gateway `FORMA_AI_MAX_TEXT_CHARS` default.
    static let maxTextCharacters = 4_000

    private static let zeroWidthScalars = CharacterSet(
        charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}"
    )

    static func validate(_ text: String) -> CoachInputValidation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .empty
        }
        if trimmed.count > maxTextCharacters {
            return .tooLong(maxCharacters: maxTextCharacters)
        }
        return .valid
    }

    /// Strips zero-width characters and normalizes common full-width forms for routing.
    /// Does not lowercase or trim
    /// meaningful food names beyond safe digit/Latin width normalization.
    static func normalizeForRouting(_ text: String) -> String {
        let withoutZeroWidth = text.unicodeScalars
            .filter { !zeroWidthScalars.contains($0) }
            .map { normalizeFullWidthScalar($0) }
            .map(String.init)
            .joined()
        return withoutZeroWidth
    }

    private static func normalizeFullWidthScalar(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let value = scalar.value
        if value >= 0xFF10, value <= 0xFF19 {
            return Unicode.Scalar(value - 0xFF10 + 0x30)!
        }
        if value >= 0xFF21, value <= 0xFF3A {
            return Unicode.Scalar(value - 0xFF21 + 0x41)!
        }
        if value >= 0xFF41, value <= 0xFF5A {
            return Unicode.Scalar(value - 0xFF41 + 0x61)!
        }
        return scalar
    }
}
