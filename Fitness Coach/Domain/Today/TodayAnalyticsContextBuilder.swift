//
//  TodayAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe Today analytics snapshots and status buckets (no PII).
//

import Foundation

struct TodayAnalyticsSnapshot: Equatable, Sendable {
    var dayStage: String
    var nextActionType: String?
    var hasMealLogged: Bool
    var proteinStatus: String
    var waterStatus: String
    var calorieStatus: String
    var workoutStatus: String
    var healthConnected: Bool

    static let empty = TodayAnalyticsSnapshot(
        dayStage: TodayAnalyticsDayStage.morning.rawValue,
        nextActionType: nil,
        hasMealLogged: false,
        proteinStatus: TodayAnalyticsNutrientStatus.behind.rawValue,
        waterStatus: TodayAnalyticsNutrientStatus.behind.rawValue,
        calorieStatus: TodayAnalyticsCalorieStatus.under.rawValue,
        workoutStatus: TodayAnalyticsWorkoutStatus.none.rawValue,
        healthConnected: false
    )
}

enum TodayAnalyticsDayStage: String, Sendable {
    case morning
    case afternoon
    case evening
    case night
}

enum TodayAnalyticsNutrientStatus: String, Sendable {
    case behind
    case onTrack = "on_track"
    case hit
}

enum TodayAnalyticsCalorieStatus: String, Sendable {
    case under
    case near
    case hit
    case over
}

enum TodayAnalyticsWorkoutStatus: String, Sendable {
    case none
    case planned
    case completed
}

enum TodayAnalyticsContextBuilder {

    static func snapshot(
        from state: TodayDashboardState,
        healthConnected: Bool,
        calendar: Calendar = .current
    ) -> TodayAnalyticsSnapshot {
        TodayAnalyticsSnapshot(
            dayStage: dayStage(for: state.date, calendar: calendar).rawValue,
            nextActionType: TodayNextActionFormatting.analyticsReason(state.nextBestAction.reason),
            hasMealLogged: !state.meals.isEmpty,
            proteinStatus: proteinStatus(from: state.macroHydration.macroSummary.protein).rawValue,
            waterStatus: waterStatus(from: state.macroHydration.waterSummary).rawValue,
            calorieStatus: calorieStatus(from: state.mission.calorieSummary).rawValue,
            workoutStatus: workoutStatus(from: state.activity).rawValue,
            healthConnected: healthConnected
        )
    }

    static func dayStage(
        for date: Date,
        calendar: Calendar = .current
    ) -> TodayAnalyticsDayStage {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    static func proteinStatus(from protein: MacroProgress) -> TodayAnalyticsNutrientStatus {
        nutrientStatus(
            consumed: protein.consumed,
            progress: protein.progress,
            onTrackThreshold: TodayFocusBuilder.proteinOnTrackThreshold
        )
    }

    static func waterStatus(from water: WaterSummary) -> TodayAnalyticsNutrientStatus {
        guard water.consumedMl > 0 else { return .behind }
        if water.progress >= 1.0 || water.consumedMl >= water.targetMl {
            return .hit
        }
        if water.progress >= TodayFocusBuilder.waterOnTrackThreshold {
            return .onTrack
        }
        return .behind
    }

    static func calorieStatus(from summary: CalorieSummary) -> TodayAnalyticsCalorieStatus {
        guard summary.consumed > 0 else { return .under }
        if summary.isOverTarget { return .over }
        if TodayPresentationBuilder.isCalorieTargetMet(summary) { return .hit }
        if TodayMissionHeroFormatter.isNearTarget(summary) { return .near }
        return .under
    }

    static func workoutStatus(from activity: TodayActivityState) -> TodayAnalyticsWorkoutStatus {
        if activity.hasWorkout {
            return .completed
        }
        if TodayActivitySectionFormatting.workoutStatus(for: activity) == .planned {
            return .planned
        }
        return .none
    }

    static func mealTypeAction(_ mealType: MealType?) -> String {
        mealType?.rawValue ?? "unspecified"
    }

    static func goalConnectionDestination(_ destination: TodayGoalConnectionDestination) -> String {
        switch destination {
        case .journey: return "journey"
        case .plan: return "plan"
        }
    }

    static func waterAmountBucket(_ amountMl: Int) -> String {
        switch amountMl {
        case ..<400: return "small"
        case 400..<700: return "medium"
        default: return "large"
        }
    }

    private static func nutrientStatus(
        consumed: Double,
        progress: Double,
        onTrackThreshold: Double
    ) -> TodayAnalyticsNutrientStatus {
        guard consumed > 0 else { return .behind }
        if progress >= 1.0 { return .hit }
        if progress >= onTrackThreshold { return .onTrack }
        return .behind
    }
}
