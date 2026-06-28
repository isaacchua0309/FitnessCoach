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
    case weekSectionViewed = "plan_week_section_viewed"
    case rationaleOpened = "plan_rationale_opened"
    case calculationDetailsOpened = "plan_calculation_details_opened"
    case activityAssumptionsViewed = "plan_activity_assumptions_viewed"
    case adjustStarted = "plan_adjust_started"
    case editSaved = "plan_edit_saved"
    case targetsRegenerated = "plan_targets_regenerated"
    case healthConnectTapped = "plan_health_connect_tapped"
    case todayTapped = "plan_today_tapped"
    case journeyTapped = "plan_journey_tapped"
}

enum PlanAnalyticsSectionImpression: Hashable, Sendable {
    case goalCard
    case todayMission
    case weekSection
    case rationale
    case activityAssumptions
}

enum PlanAnalyticsHealthConnectEntryPoint: String, Sendable {
    case trainingIntegrationCard = "training_integration_card"
    case activityAssumptions = "activity_assumptions"
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
    static let activityAssumptions = "plan_activity_assumptions"
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
