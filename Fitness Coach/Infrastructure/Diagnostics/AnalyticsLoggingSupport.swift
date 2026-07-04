//
//  AnalyticsLoggingSupport.swift
//  Fitness Coach
//
//  Forma — Shared analytics sink helpers (privacy, naming, Release posture).
//
//  Registry: Docs/Architecture/AnalyticsReadinessChecklist.md
//

import Foundation

enum AnalyticsLoggingSupport {

    /// Parameter keys that must never appear in analytics sinks.
    static let bannedParameterKeys: Set<String> = [
        "food_name", "meal_name", "food_text", "review_text", "daily_review",
        "weight_kg", "weight_value", "goal_weight", "current_weight",
        "calories", "protein", "carbs", "fat", "user_message", "coach_message",
        "uid", "email", "token", "base64", "payload", "snapshot_json"
    ]

    /// Substrings that must not appear in analytics parameter values.
    static let bannedValueSubstrings: [String] = [
        "bearer ", "eyj", "chicken", "salad", "breakfast", "lunch", "dinner",
        "@", "users/"
    ]

    /// Applies shared log redaction to analytics parameter dictionaries.
    static func privacySafeParameters(_ raw: [String: String]) -> [String: String] {
        LogRedactor.sanitizeLogFields(raw)
    }

    /// Returns `true` when parameters contain no banned keys or sensitive value patterns.
    static func isPrivacySafe(_ parameters: [String: String]) -> Bool {
        for (key, value) in parameters {
            let loweredKey = key.lowercased()
            if bannedParameterKeys.contains(loweredKey) {
                return false
            }
            if LogRedactor.isSensitiveFieldKey(loweredKey) {
                return false
            }
            let loweredValue = value.lowercased()
            for banned in bannedValueSubstrings where loweredValue.contains(banned) {
                return false
            }
            if LogRedactor.isSensitiveFieldValue(value) {
                return false
            }
        }
        return true
    }

    /// Validates analytics event names follow `{domain}_{action}` snake_case.
    static func isValidEventName(_ name: String) -> Bool {
        let pattern = #"^[a-z][a-z0-9]*(_[a-z0-9]+)+$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}

protocol AnalyticsParameterBag {
    func asParameters() -> [String: String]
}

extension TodayAnalyticsProperties: AnalyticsParameterBag {}
extension JourneyAnalyticsProperties: AnalyticsParameterBag {}
extension PlanAnalyticsProperties: AnalyticsParameterBag {}
extension OnboardingAnalyticsProperties: AnalyticsParameterBag {}
extension SettingsAnalyticsProperties: AnalyticsParameterBag {}
extension HealthIntelligenceAnalyticsProperties: AnalyticsParameterBag {}
extension PublicEntryAnalyticsProperties: AnalyticsParameterBag {}
extension ThemeAnalyticsProperties: AnalyticsParameterBag {}
extension CoachAnalyticsProperties: AnalyticsParameterBag {}

extension AnalyticsParameterBag {

    /// Privacy-sanitized parameters for production analytics sinks.
    func privacySafeParameters() -> [String: String] {
        AnalyticsLoggingSupport.privacySafeParameters(asParameters())
    }
}
