//
//  CoachAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Coach analytics events and safe property bag.
//

import Foundation

enum CoachAnalyticsEvent: String, Sendable {
    case nutritionEstimateCardShown = "nutrition_estimate_card_shown"
    case nutritionComparisonCardShown = "nutrition_comparison_card_shown"
    case nutritionEstimateJSONParseFailed = "nutrition_estimate_json_parse_failed"
    case nutritionEstimateActionTapped = "nutrition_estimate_action_tapped"
    case nutritionEstimateLogStarted = "nutrition_estimate_log_started"
    case nutritionEstimateLogConfirmed = "nutrition_estimate_log_confirmed"
    case nutritionEstimateLogCancelled = "nutrition_estimate_log_cancelled"
}

struct CoachAnalyticsProperties: Sendable {
    var confidenceLevel: String?
    var hasMacros: Bool?
    var hasTodayContext: Bool?
    var actionType: String?
    var sourceType: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let confidenceLevel { parameters["confidenceLevel"] = confidenceLevel }
        if let hasMacros { parameters["hasMacros"] = hasMacros ? "true" : "false" }
        if let hasTodayContext { parameters["hasTodayContext"] = hasTodayContext ? "true" : "false" }
        if let actionType { parameters["actionType"] = actionType }
        if let sourceType { parameters["sourceType"] = sourceType }
        return parameters
    }
}

protocol CoachAnalyticsLogging: Sendable {
    func log(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties)
}

struct NoOpCoachAnalyticsLogger: CoachAnalyticsLogging {
    func log(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties) {}
}

#if DEBUG
struct OSLogCoachAnalyticsLogger: CoachAnalyticsLogging {
    func log(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties) {
        FormaPipelineTracer.event(
            stage: .aiTask,
            level: .debug,
            message: "Coach analytics",
            fields: ["event": event.rawValue].merging(properties.asParameters()) { _, new in new }
        )
    }
}
#endif
