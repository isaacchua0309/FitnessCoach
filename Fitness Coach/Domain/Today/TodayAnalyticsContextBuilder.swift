//
//  TodayAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe Today analytics snapshots and progress buckets (no PII).
//

import Foundation

struct TodayAnalyticsSnapshot: Equatable, Sendable {
    var hasMeals: Bool
    var calorieProgressBucket: String
    var proteinProgressBucket: String
    var healthConnected: Bool
    var nextActionReason: String?

    static let empty = TodayAnalyticsSnapshot(
        hasMeals: false,
        calorieProgressBucket: TodayAnalyticsProgressBucket.none.rawValue,
        proteinProgressBucket: TodayAnalyticsProgressBucket.none.rawValue,
        healthConnected: false,
        nextActionReason: nil
    )
}

enum TodayAnalyticsProgressBucket: String, Sendable {
    case none
    case low
    case mid
    case onTrack = "on_track"
    case over
}

enum TodayAnalyticsContextBuilder {

    static func snapshot(
        from state: TodayDashboardState,
        healthConnected: Bool
    ) -> TodayAnalyticsSnapshot {
        TodayAnalyticsSnapshot(
            hasMeals: !state.meals.isEmpty,
            calorieProgressBucket: calorieBucket(from: state.mission.calorieSummary),
            proteinProgressBucket: proteinBucket(from: state.macroBalance.macroSummary.protein),
            healthConnected: healthConnected,
            nextActionReason: TodayNextActionFormatting.analyticsReason(state.nextBestAction.reason)
        )
    }

    static func calorieBucket(from summary: CalorieSummary) -> String {
        guard summary.consumed > 0 else {
            return TodayAnalyticsProgressBucket.none.rawValue
        }
        if summary.isOverTarget {
            return TodayAnalyticsProgressBucket.over.rawValue
        }
        return progressBucket(for: summary.progress).rawValue
    }

    static func proteinBucket(from protein: MacroProgress) -> String {
        guard protein.consumed > 0 else {
            return TodayAnalyticsProgressBucket.none.rawValue
        }
        return progressBucket(for: protein.progress).rawValue
    }

    static func progressBucket(for progress: Double) -> TodayAnalyticsProgressBucket {
        if progress >= 1.0 {
            return .over
        }
        if progress >= 0.9 {
            return .onTrack
        }
        if progress >= 0.5 {
            return .mid
        }
        return .low
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
}
