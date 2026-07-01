//
//  PlanAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe Plan analytics snapshots and buckets (no PII).
//

import Foundation

struct PlanAnalyticsSnapshot: Equatable, Sendable {
    var goalType: String
    var calorieTargetBucket: String
    var progressBucket: String
    var healthConnected: Bool
    var activityLevel: String
}

enum PlanAnalyticsCalorieTargetBucket: String, Sendable {
    case under1800 = "under_1800"
    case _1800to2199 = "1800_2199"
    case _2200to2599 = "2200_2599"
    case _2600plus = "2600_plus"
}

enum PlanAnalyticsGoalProgressBucket: String, Sendable {
    case unknown
    case none
    case low
    case mid
    case onTrack = "on_track"
    case complete
}

enum PlanAnalyticsContextBuilder {

    static func snapshot(
        from state: PlanDashboardState,
        healthConnected: Bool
    ) -> PlanAnalyticsSnapshot {
        PlanAnalyticsSnapshot(
            goalType: goalType(for: state.profile),
            calorieTargetBucket: calorieTargetBucket(state.profile.targets.calorieTarget),
            progressBucket: progressBucket(from: state.missionControl.mission),
            healthConnected: healthConnected,
            activityLevel: activityLevel(state.profile.activityLevel)
        )
    }

    static func goalType(for profile: UserProfile) -> String {
        switch PlanStateBuilder.goalType(for: profile) {
        case .loseFat: return "lose"
        case .gainMuscle: return "gain"
        case .maintain: return "maintain"
        }
    }

    static func calorieTargetBucket(_ kcal: Int) -> String {
        switch kcal {
        case ..<1800: return PlanAnalyticsCalorieTargetBucket.under1800.rawValue
        case 1800..<2200: return PlanAnalyticsCalorieTargetBucket._1800to2199.rawValue
        case 2200..<2600: return PlanAnalyticsCalorieTargetBucket._2200to2599.rawValue
        default: return PlanAnalyticsCalorieTargetBucket._2600plus.rawValue
        }
    }

    static func progressBucket(from mission: PlanMissionState) -> String {
        guard let progress = mission.progressPercent else {
            return mission.showsProgressBar
                ? PlanAnalyticsGoalProgressBucket.none.rawValue
                : PlanAnalyticsGoalProgressBucket.unknown.rawValue
        }
        if progress >= 1.0 {
            return PlanAnalyticsGoalProgressBucket.complete.rawValue
        }
        if progress >= 0.75 {
            return PlanAnalyticsGoalProgressBucket.onTrack.rawValue
        }
        if progress >= 0.35 {
            return PlanAnalyticsGoalProgressBucket.mid.rawValue
        }
        return PlanAnalyticsGoalProgressBucket.low.rawValue
    }

    static func activityLevel(_ level: ActivityLevel) -> String {
        level.rawValue
    }
}
