//
//  PlanAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Plan analytics events and safe property bag.
//  Weekly progress plan recommendation events live in `WeeklyProgressAnalyticsLogging.swift`.
//
//  Contract: Docs/Architecture/AnalyticsReadinessChecklist.md
//

import Foundation

enum PlanAnalyticsEvent: String, Sendable {
    case viewed = "plan_viewed"
    case strategyViewed = "plan_strategy_viewed"
    case statusViewed = "plan_status_viewed"
    case confidenceViewed = "plan_confidence_viewed"
    case adjustCTATapped = "plan_adjust_cta_tapped"
    case calculationTapped = "plan_calculation_tapped"
    case activityUpdateTapped = "plan_activity_update_tapped"
    case adjustStarted = "plan_adjust_started"
    case editSaved = "plan_edit_saved"
    case targetsRegenerated = "plan_targets_regenerated"
    case healthConnectTapped = "plan_health_connect_tapped"
    case todayTapped = "plan_today_tapped"
}

enum PlanAnalyticsSectionImpression: Hashable, Sendable {
    case strategy
    case status
    case confidence
}

enum PlanAnalyticsHealthConnectEntryPoint: String, Sendable {
    case planConfidence = "plan_confidence"
}

struct PlanAnalyticsProperties: Sendable {
    var planType: String?
    var confidenceBucket: String?
    var appleHealthConnected: Bool?
    var hasRecentWeighIn: Bool?
    var hasEnoughFoodLogs: Bool?
    var entryPoint: String?
    var initialStep: Int?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let planType { parameters["plan_type"] = planType }
        if let confidenceBucket { parameters["confidence_bucket"] = confidenceBucket }
        if let appleHealthConnected {
            parameters["apple_health_connected"] = appleHealthConnected ? "true" : "false"
        }
        if let hasRecentWeighIn {
            parameters["has_recent_weigh_in"] = hasRecentWeighIn ? "true" : "false"
        }
        if let hasEnoughFoodLogs {
            parameters["has_enough_food_logs"] = hasEnoughFoodLogs ? "true" : "false"
        }
        if let entryPoint { parameters["entry_point"] = entryPoint }
        if let initialStep { parameters["initial_step"] = String(initialStep) }
        return parameters
    }
}

protocol PlanAnalyticsLogging: Sendable {
    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties)
}

enum PlanAdjustPlanEntryPoint: String, Sendable {
    case planTab = "plan_dashboard"
    case onboarding = "onboarding"
    case weeklyReview = "weekly_review"
    case journeyRecommendation = "journey_recommendation"
    case planAssumptions = "plan_assumptions"
    case adjustPlanCTA = "plan_adjust_cta"
    case settingsBodyDetails = "settings_body_details"

    /// Legacy alias used by toolbar and bottom CTA entry points.
    static let dashboard = PlanAdjustPlanEntryPoint.planTab
}

extension PlanAnalyticsProperties {

    static func from(snapshot: PlanAnalyticsSnapshot) -> PlanAnalyticsProperties {
        PlanAnalyticsProperties(
            planType: snapshot.planType,
            confidenceBucket: snapshot.confidenceBucket,
            appleHealthConnected: snapshot.appleHealthConnected,
            hasRecentWeighIn: snapshot.hasRecentWeighIn,
            hasEnoughFoodLogs: snapshot.hasEnoughFoodLogs
        )
    }

    mutating func merge(snapshot: PlanAnalyticsSnapshot) {
        planType = snapshot.planType
        confidenceBucket = snapshot.confidenceBucket
        appleHealthConnected = snapshot.appleHealthConnected
        hasRecentWeighIn = snapshot.hasRecentWeighIn
        hasEnoughFoodLogs = snapshot.hasEnoughFoodLogs
    }
}
