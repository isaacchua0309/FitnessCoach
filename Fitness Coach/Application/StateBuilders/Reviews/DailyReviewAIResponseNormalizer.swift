//
//  DailyReviewAIResponseNormalizer.swift
//  Fitness Coach
//
//  Validates and normalizes structured daily review AI copy.
//

import Foundation

enum DailyReviewAIResponseNormalizer {

    static func normalize(
        _ response: DailyReviewAIResponse,
        summary: DailyReviewSummary,
        contextHints: CoachResponseContextHints? = nil
    ) -> DailyReviewAIResponse? {
        let statusSummary = sanitizeRequiredField(
            response.statusSummary,
            maxLength: DailyReviewContentContract.maxStatusSummaryLength,
            summary: summary
        )
        let bestNextMove = sanitizeRequiredField(
            response.bestNextMove,
            maxLength: DailyReviewContentContract.maxBestNextMoveLength,
            summary: summary
        )

        guard let statusSummary, let bestNextMove else { return nil }

        let tomorrowFocus = sanitizeOptionalField(
            response.tomorrowFocus,
            maxLength: DailyReviewContentContract.maxTomorrowFocusLength,
            summary: summary
        )
        let detailNote = sanitizeOptionalField(
            response.detailNote,
            maxLength: DailyReviewContentContract.maxDetailNoteLength,
            summary: summary
        )

        let normalized = DailyReviewAIResponse(
            statusSummary: statusSummary,
            bestNextMove: bestNextMove,
            tomorrowFocus: tomorrowFocus,
            missingSignals: normalizedMissingSignals(
                aiSignals: response.missingSignals,
                contextHints: contextHints
            ),
            detailNote: detailNote
        )

        return validates(normalized) ? normalized : nil
    }

    static func validates(_ response: DailyReviewAIResponse) -> Bool {
        guard !response.statusSummary.isEmpty,
              !response.bestNextMove.isEmpty else {
            return false
        }

        guard response.statusSummary.count <= DailyReviewContentContract.maxStatusSummaryLength,
              response.bestNextMove.count <= DailyReviewContentContract.maxBestNextMoveLength,
              (response.tomorrowFocus?.count ?? 0) <= DailyReviewContentContract.maxTomorrowFocusLength,
              (response.detailNote?.count ?? 0) <= DailyReviewContentContract.maxDetailNoteLength else {
            return false
        }

        let fields = [
            response.statusSummary,
            response.bestNextMove,
            response.tomorrowFocus,
            response.detailNote
        ].compactMap { $0 }

        return fields.allSatisfy { !looksLikeParagraph($0) && !containsHeaderProse($0) }
    }

    // MARK: - Sanitization

    private static func sanitizeRequiredField(
        _ text: String,
        maxLength: Int,
        summary: DailyReviewSummary
    ) -> String? {
        let sanitized = sanitizeField(text, maxLength: maxLength, summary: summary)
        return sanitized?.isEmpty == false ? sanitized : nil
    }

    private static func sanitizeOptionalField(
        _ text: String?,
        maxLength: Int,
        summary: DailyReviewSummary
    ) -> String? {
        guard let text else { return nil }
        let sanitized = sanitizeField(text, maxLength: maxLength, summary: summary)
        guard let sanitized, !sanitized.isEmpty else { return nil }
        return sanitized
    }

    private static func sanitizeField(
        _ text: String,
        maxLength: Int,
        summary: DailyReviewSummary
    ) -> String? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        trimmed = stripHeaderProse(trimmed)
        trimmed = stripUnavailableDataSentences(trimmed)
        trimmed = firstSentence(from: trimmed)
        trimmed = stripFalsePraise(trimmed, summary: summary)
        trimmed = compactText(trimmed, maxLength: maxLength)

        guard !trimmed.isEmpty, !looksLikeParagraph(trimmed) else { return nil }
        return trimmed
    }

    private static func normalizedMissingSignals(
        aiSignals: [String]?,
        contextHints: CoachResponseContextHints?
    ) -> [String] {
        let deterministic = DailyReviewPayloadBuilder.missingSignalLabels(
            from: contextHints?.missingData
        )
        guard !deterministic.isEmpty else {
            return shortMissingSignalLabels(from: aiSignals)
        }
        return deterministic
    }

    private static func shortMissingSignalLabels(from aiSignals: [String]?) -> [String] {
        guard let aiSignals else { return [] }
        let allowed = Set(["Steps", "Workout", "Sleep", "HRV"])
        return aiSignals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { allowed.contains($0) }
    }

    private static func stripHeaderProse(_ text: String) -> String {
        var result = text
        if let range = result.range(
            of: #"^Daily review\s*\([^)]+\)\s*:\s*"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            result.removeSubrange(range)
        }
        if let range = result.range(
            of: #"^Daily review\s*:\s*"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            result.removeSubrange(range)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsHeaderProse(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("daily review (")
            || normalized.hasPrefix("daily review:")
    }

    private static func stripUnavailableDataSentences(_ text: String) -> String {
        let patterns = [
            #"[^.!?]*apple health[^.!?]*[.!?]"#,
            #"[^.!?]*isn'?t available[^.!?]*[.!?]"#,
            #"[^.!?]*not available right now[^.!?]*[.!?]"#,
            #"[^.!?]*unavailable[^.!?]*[.!?]"#
        ]

        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstSentence(from text: String) -> String {
        let parts = text.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { ".!?".contains($0) }
        )
        guard let first = parts.first else { return text }
        let sentence = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? text : sentence
    }

    private static func stripFalsePraise(_ text: String, summary: DailyReviewSummary) -> String {
        guard containsWinLanguage(text), !hasCompletedPositiveOutcome(summary) else {
            return text
        }
        return ""
    }

    private static func containsWinLanguage(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("win")
            || normalized.contains("great job")
            || normalized.contains("crushed it")
            || normalized.contains("amazing")
    }

    private static func hasCompletedPositiveOutcome(_ summary: DailyReviewSummary) -> Bool {
        let hasLogs = summary.foodEntryCount > 0
            || summary.caloriesConsumed > 0
            || summary.proteinConsumed > 0
            || summary.waterConsumedMl > 0
        guard hasLogs else { return false }

        let metCalories = summary.caloriesConsumed > 0 && !summary.isOverCalorieTarget
        let metProtein = summary.proteinConsumed > 0 && summary.hasMetProteinTarget
        let metWater = summary.waterConsumedMl > 0 && summary.hasMetWaterTarget
        return metCalories || metProtein || metWater
    }

    private static func looksLikeParagraph(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceCount = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        return sentenceCount > 2 || trimmed.contains("\n\n")
    }

    private static func compactText(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
