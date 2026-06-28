//
//  TodayAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Today analytics events and safe property bag.
//

import Foundation

enum TodayAnalyticsEvent: String, Sendable {
    case viewed = "today_viewed"
    case nextActionViewed = "today_next_action_viewed"
    case nextActionTapped = "today_next_action_tapped"
    case quickActionTapped = "today_quick_action_tapped"
    case logMealStarted = "today_log_meal_started"
    case logMealSaved = "today_log_meal_saved"
    case mealEditStarted = "today_meal_edit_started"
    case mealEditSaved = "today_meal_edit_saved"
    case mealDeleted = "today_meal_deleted"
    case waterAdded = "today_water_added"
    case weightLogged = "today_weight_logged"
    case scanFoodTapped = "today_scan_food_tapped"
    case goalConnectionTapped = "today_goal_connection_tapped"
}

struct TodayAnalyticsProperties: Sendable {
    var hasMeals: Bool?
    var calorieProgressBucket: String?
    var proteinProgressBucket: String?
    var healthConnected: Bool?
    var actionType: String?
    var reason: String?
    var cta: String?
    var route: String?
    var action: String?
    var mealType: String?
    var waterAmountBucket: String?
    var destination: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let hasMeals { parameters["hasMeals"] = hasMeals ? "true" : "false" }
        if let calorieProgressBucket { parameters["calorieProgressBucket"] = calorieProgressBucket }
        if let proteinProgressBucket { parameters["proteinProgressBucket"] = proteinProgressBucket }
        if let healthConnected { parameters["healthConnected"] = healthConnected ? "true" : "false" }
        if let actionType { parameters["actionType"] = actionType }
        if let reason { parameters["reason"] = reason }
        if let cta { parameters["cta"] = cta }
        if let route { parameters["route"] = route }
        if let action { parameters["action"] = action }
        if let mealType { parameters["mealType"] = mealType }
        if let waterAmountBucket { parameters["waterAmountBucket"] = waterAmountBucket }
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
        reason: String? = nil,
        cta: String? = nil,
        route: String? = nil,
        action: String? = nil,
        mealType: String? = nil,
        waterAmountBucket: String? = nil,
        destination: String? = nil
    ) -> TodayAnalyticsProperties {
        TodayAnalyticsProperties(
            hasMeals: snapshot.hasMeals,
            calorieProgressBucket: snapshot.calorieProgressBucket,
            proteinProgressBucket: snapshot.proteinProgressBucket,
            healthConnected: snapshot.healthConnected,
            actionType: actionType,
            reason: reason ?? snapshot.nextActionReason,
            cta: cta,
            route: route,
            action: action,
            mealType: mealType,
            waterAmountBucket: waterAmountBucket,
            destination: destination
        )
    }
}
