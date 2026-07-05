//
//  TodayAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Today analytics events and safe property bag.
//
//  Contract: Docs/Architecture/AnalyticsReadinessChecklist.md
//  Release: NoOp sink (events not persisted). DEBUG: OSLog via AppContainer.
//

import Foundation

enum TodayAnalyticsEvent: String, Sendable {
    case viewed = "today_viewed"
    case missionViewed = "today_mission_viewed"
    case primaryCTATapped = "today_primary_cta_tapped"
    case nextBestActionViewed = "today_next_best_action_viewed"
    case nextBestActionTapped = "today_next_best_action_tapped"
    case quickActionTapped = "today_quick_action_tapped"
    case mealAddTapped = "today_meal_add_tapped"
    case mealEditTapped = "today_meal_edit_tapped"
    case dailyVictoryViewed = "today_daily_victory_viewed"
    case smartCoachViewed = "today_smart_coach_viewed"
    case endOfDayWrapViewed = "today_end_of_day_wrap_viewed"
    case yesterdayReviewViewed = "today_yesterday_review_viewed"
    case yesterdayReviewTapped = "today_yesterday_review_tapped"
    case logMealSaved = "today_log_meal_saved"
    case mealEditSaved = "today_meal_edit_saved"
    case mealDeleted = "today_meal_deleted"
    case waterAdded = "today_water_added"
    case weightLogged = "today_weight_logged"
    case scanFoodTapped = "today_scan_food_tapped"
    case goalConnectionTapped = "today_goal_connection_tapped"
}

struct TodayAnalyticsProperties: Sendable {
    var dayStage: String?
    var nextActionType: String?
    var hasMealLogged: Bool?
    var proteinStatus: String?
    var waterStatus: String?
    var calorieStatus: String?
    var workoutStatus: String?
    var healthConnected: Bool?
    var actionType: String?
    var cta: String?
    var route: String?
    var action: String?
    var mealType: String?
    var waterAmountBucket: String?
    var destination: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let dayStage { parameters["day_stage"] = dayStage }
        if let nextActionType { parameters["next_action_type"] = nextActionType }
        if let hasMealLogged { parameters["has_meal_logged"] = hasMealLogged ? "true" : "false" }
        if let proteinStatus { parameters["protein_status"] = proteinStatus }
        if let waterStatus { parameters["water_status"] = waterStatus }
        if let calorieStatus { parameters["calorie_status"] = calorieStatus }
        if let workoutStatus { parameters["workout_status"] = workoutStatus }
        if let healthConnected { parameters["health_connected"] = healthConnected ? "true" : "false" }
        if let actionType { parameters["action_type"] = actionType }
        if let cta { parameters["cta"] = cta }
        if let route { parameters["route"] = route }
        if let action { parameters["action"] = action }
        if let mealType { parameters["meal_type"] = mealType }
        if let waterAmountBucket { parameters["water_amount_bucket"] = waterAmountBucket }
        if let destination { parameters["destination"] = destination }
        return parameters
    }
}

protocol TodayAnalyticsLogging: Sendable {
    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties)
}

extension TodayAnalyticsProperties {

    static func from(
        snapshot: TodayAnalyticsSnapshot,
        actionType: String? = nil,
        cta: String? = nil,
        route: String? = nil,
        action: String? = nil,
        mealType: String? = nil,
        waterAmountBucket: String? = nil,
        destination: String? = nil
    ) -> TodayAnalyticsProperties {
        TodayAnalyticsProperties(
            dayStage: snapshot.dayStage,
            nextActionType: snapshot.nextActionType,
            hasMealLogged: snapshot.hasMealLogged,
            proteinStatus: snapshot.proteinStatus,
            waterStatus: snapshot.waterStatus,
            calorieStatus: snapshot.calorieStatus,
            workoutStatus: snapshot.workoutStatus,
            healthConnected: snapshot.healthConnected,
            actionType: actionType,
            cta: cta,
            route: route,
            action: action,
            mealType: mealType,
            waterAmountBucket: waterAmountBucket,
            destination: destination
        )
    }
}
