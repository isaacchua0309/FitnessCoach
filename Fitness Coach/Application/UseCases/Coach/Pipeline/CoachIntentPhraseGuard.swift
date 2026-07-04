//
//  CoachIntentPhraseGuard.swift
//  Fitness Coach
//
//  Deterministic guards that keep advice, lookup, and hypothetical food questions
//  from being misclassified as log_food.
//

import Foundation

enum CoachIntentPhraseGuard {

    /// Higher bar when a question-form message was classified as log_food.
    static let logFoodQuestionThreshold = 0.85

    static func hasExplicitLoggingIntent(_ text: String) -> Bool {
        let normalized = normalize(text)

        let explicitPatterns = [
            #"^(log|add|track|record)\b"#,
            #"\b(log this|log that|add this|add that)\b"#,
            #"^(i )?(just )?(ate|had|eaten|consumed)\b"#,
            #"\bi (just )?(ate|had|finished eating)\b"#,
            #"\badd .+ to (breakfast|lunch|dinner|snack|my (breakfast|lunch|dinner))\b"#,
            #"\blog .+ (for|to) (breakfast|lunch|dinner|snack)\b"#,
            #"\b(log|add) same as\b"#,
            #"\b(i ate|i had) (the )?same as\b"#,
            #"\bplease log\b"#,
            #"\bput .+ in (my )?(log|diary)\b"#
        ]

        return explicitPatterns.contains {
            normalized.range(of: $0, options: .regularExpression) != nil
        }
    }

    static func isAmbiguousAdvicePhrase(_ text: String) -> Bool {
        if hasExplicitLoggingIntent(text) { return false }

        let normalized = normalize(text)
        let patterns = [
            #"^(should i|can i|could i|may i)\b"#,
            #"\bshould i (eat|have|order|get|try)\b"#,
            #"\bcan i (eat|have|fit|afford|order|get)\b"#,
            #"\bcould i (eat|have|fit)\b"#,
            #"\bwould it be okay\b"#,
            #"\bis it okay (to|if|for me)\b"#,
            #"\bis .+ okay\b"#,
            #"\bis .+ healthy\b"#,
            #"^how many calories\b"#,
            #"\bcalories in\b"#,
            #"\bhow much (protein|carbs|fat|calories) in\b"#,
            #"^what should i eat\b"#,
            #"\bwhat should i (have|order|get)\b"#,
            #"\brecommend (me|a|something)\b"#,
            #"\bwould .+ fit\b"#,
            #"\bfit my (calories|macros|calorie|protein)\b"#,
            #"^what was (breakfast|lunch|dinner|my breakfast|my lunch|my dinner)\b"#,
            #"\bwhat did i (eat|have) (for )?(breakfast|lunch|dinner)\b"#
        ]

        return patterns.contains {
            normalized.range(of: $0, options: .regularExpression) != nil
        }
    }

    static func isReferenceOnlyWithoutLogging(_ text: String) -> Bool {
        if hasExplicitLoggingIntent(text) { return false }
        return normalize(text).contains("same as")
    }

    static func isQuestionForm(_ text: String) -> Bool {
        let normalized = normalize(text)
        if normalized.hasSuffix("?") { return true }
        return isAmbiguousAdvicePhrase(text)
    }

    static func suggestedIntent(for text: String) -> CoachIntent {
        let normalized = normalize(text)

        if normalized.contains(" vs ") || normalized.contains(" versus ") {
            return .nutritionComparisonQuery
        }
        if normalized.contains("recommend")
            || normalized.hasPrefix("what should i eat")
            || normalized.contains("what should i have") {
            return .nutritionAdvice
        }
        if normalized.contains("calories")
            || normalized.contains("how many")
            || normalized.contains("how much")
            || normalized.hasPrefix("what was")
            || normalized.contains("what did i eat")
            || normalized.contains("what did i have") {
            return .nutritionEstimateQuery
        }
        return .mealDecision
    }

    static func applyGuards(to result: CoachIntentResult, text: String) -> CoachIntentResult {
        guard !hasExplicitLoggingIntent(text) else { return result }

        let needsCorrection =
            (result.intent == .logFood && (isAmbiguousAdvicePhrase(text) || isReferenceOnlyWithoutLogging(text)))
            || (isAmbiguousAdvicePhrase(text) && (result.requiresAppMutation || result.action != nil))
            || (isReferenceOnlyWithoutLogging(text) && (result.intent == .logFood || result.action != nil))

        guard needsCorrection else { return result }

        var copy = result
        if copy.intent == .logFood || copy.action != nil {
            copy.intent = suggestedIntent(for: text)
            copy.requiresAppMutation = false
            copy.action = nil
            if copy.reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                copy.reason = "Advice or lookup phrasing without explicit logging intent."
            }
        }

        traceGuardApplied(originalIntent: result.intent, correctedIntent: copy.intent, text: text)
        return copy
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func traceGuardApplied(
        originalIntent: CoachIntent,
        correctedIntent: CoachIntent,
        text: String
    ) {
        guard originalIntent != correctedIntent else { return }
        FormaPipelineTracer.event(
            stage: .classify,
            level: .debug,
            message: "Coach intent phrase guard corrected classification",
            fields: [
                "fromIntent": originalIntent.rawValue,
                "toIntent": correctedIntent.rawValue,
                "textLength": String(text.count)
            ]
        )
    }
}
