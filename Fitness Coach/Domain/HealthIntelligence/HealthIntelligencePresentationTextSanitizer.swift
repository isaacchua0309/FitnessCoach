//
//  HealthIntelligencePresentationTextSanitizer.swift
//  Fitness Coach
//
//  Forma — Strips raw metric language from Health Intelligence presentation copy.
//

import Foundation

enum HealthIntelligencePresentationTextSanitizer {

    private static let riskyMetricSubstrings = [
        "hrv",
        "heart rate",
        "resting heart",
        "bpm",
        " ms",
        "millisecond",
        "baseline",
        "below your recent",
        "above your recent"
    ]

    static func sanitize(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !containsRiskyMetricLanguage(trimmed) else { return nil }
        return trimmed
    }

    static func containsRiskyMetricLanguage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return riskyMetricSubstrings.contains { lower.contains($0) }
    }
}
