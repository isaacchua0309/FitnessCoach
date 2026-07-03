//
//  PlanAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Plan analytics events and safe property bag.
//

import Foundation

enum PlanAnalyticsEvent: String, Sendable {
    case viewed = "plan_viewed"
    case goalCardViewed = "plan_goal_card_viewed"
    case todayMissionViewed = "plan_today_mission_viewed"
    case rationaleOpened = "plan_rationale_opened"
    case calculationDetailsOpened = "plan_calculation_details_opened"
    case planAssumptionsViewed = "plan_assumptions_viewed"
    case adjustStarted = "plan_adjust_started"
    case editSaved = "plan_edit_saved"
    case targetsRegenerated = "plan_targets_regenerated"
    case healthConnectTapped = "plan_health_connect_tapped"
    case todayTapped = "plan_today_tapped"
}

enum PlanAnalyticsSectionImpression: Hashable, Sendable {
    case goalCard
    case todayMission
    case rationale
    case planAssumptions
}

enum PlanAnalyticsHealthConnectEntryPoint: String, Sendable {
    case planConfidence = "plan_confidence"
}

struct PlanAnalyticsProperties: Sendable {
    var goalType: String?
    var calorieTargetBucket: String?
    var progressBucket: String?
    var healthConnected: Bool?
    var activityLevel: String?
    var entryPoint: String?
    var initialStep: Int?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let goalType { parameters["goalType"] = goalType }
        if let calorieTargetBucket { parameters["calorieTargetBucket"] = calorieTargetBucket }
        if let progressBucket { parameters["progressBucket"] = progressBucket }
        if let healthConnected { parameters["healthConnected"] = healthConnected ? "true" : "false" }
        if let activityLevel { parameters["activityLevel"] = activityLevel }
        if let entryPoint { parameters["entryPoint"] = entryPoint }
        if let initialStep { parameters["initialStep"] = String(initialStep) }
        return parameters
    }
}

protocol PlanAnalyticsLogging: Sendable {
    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties)
}

enum PlanAdjustPlanEntryPoint {
    static let dashboard = "plan_dashboard"
    static let planAssumptions = "plan_assumptions"
}

extension PlanAnalyticsProperties {

    static func from(snapshot: PlanAnalyticsSnapshot) -> PlanAnalyticsProperties {
        PlanAnalyticsProperties(
            goalType: snapshot.goalType,
            calorieTargetBucket: snapshot.calorieTargetBucket,
            progressBucket: snapshot.progressBucket,
            healthConnected: snapshot.healthConnected,
            activityLevel: snapshot.activityLevel
        )
    }

    mutating func merge(snapshot: PlanAnalyticsSnapshot) {
        goalType = snapshot.goalType
        calorieTargetBucket = snapshot.calorieTargetBucket
        progressBucket = snapshot.progressBucket
        healthConnected = snapshot.healthConnected
        activityLevel = snapshot.activityLevel
    }
}
