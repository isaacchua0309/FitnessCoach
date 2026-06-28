//
//  JourneyAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Journey analytics events and safe property bag.
//

import Foundation

enum JourneyAnalyticsEvent: String, Sendable {
    case screenViewed = "journey_screen_viewed"
    case transformationViewed = "journey_transformation_viewed"
    case weeklyReviewViewed = "journey_weekly_review_viewed"
    case milestoneRailViewed = "journey_milestone_rail_viewed"
    case timelineViewed = "journey_timeline_viewed"
    case habitInsightViewed = "journey_habit_insight_viewed"
    case weightCTATapped = "journey_weight_cta_tapped"
    case coachCTATapped = "journey_coach_cta_tapped"
    case analyticsExpanded = "journey_analytics_expanded"
    case rangeChanged = "journey_range_changed"
}

struct JourneyAnalyticsSnapshot: Equatable, Sendable {
    var hasProfile: Bool
    var hasWeightLogs: Bool
    var usesSyntheticBaseline: Bool
    var progressPercentBucket: String
    var currentStreakBucket: String
    var unlockedMilestoneCount: Int
    var healthConnected: Bool
    var journeyLevel: Int

    static let empty = JourneyAnalyticsSnapshot(
        hasProfile: false,
        hasWeightLogs: false,
        usesSyntheticBaseline: false,
        progressPercentBucket: JourneyAnalyticsProgressPercentBucket.none.rawValue,
        currentStreakBucket: JourneyAnalyticsStreakBucket.zero.rawValue,
        unlockedMilestoneCount: 0,
        healthConnected: false,
        journeyLevel: 1
    )
}

enum JourneyAnalyticsProgressPercentBucket: String, Sendable {
    case none
    case low = "1_10"
    case building = "11_25"
    case mid = "26_50"
    case strong = "51_75"
    case nearComplete = "76_99"
    case complete
}

enum JourneyAnalyticsStreakBucket: String, Sendable {
    case zero = "0"
    case short = "1_3"
    case week = "4_7"
    case twoWeeks = "8_14"
    case long = "15_plus"
}

struct JourneyAnalyticsProperties: Sendable {
    var hasProfile: Bool?
    var hasWeightLogs: Bool?
    var usesSyntheticBaseline: Bool?
    var progressPercentBucket: String?
    var currentStreakBucket: String?
    var unlockedMilestoneCount: Int?
    var healthConnected: Bool?
    var journeyLevel: Int?
    var rangeDays: Int?
    var ctaType: String?
    var expanded: Bool?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let hasProfile { parameters["has_profile"] = hasProfile ? "true" : "false" }
        if let hasWeightLogs { parameters["has_weight_logs"] = hasWeightLogs ? "true" : "false" }
        if let usesSyntheticBaseline {
            parameters["uses_synthetic_baseline"] = usesSyntheticBaseline ? "true" : "false"
        }
        if let progressPercentBucket { parameters["progress_percent_bucket"] = progressPercentBucket }
        if let currentStreakBucket { parameters["current_streak_bucket"] = currentStreakBucket }
        if let unlockedMilestoneCount {
            parameters["unlocked_milestone_count"] = String(unlockedMilestoneCount)
        }
        if let healthConnected { parameters["health_connected"] = healthConnected ? "true" : "false" }
        if let journeyLevel { parameters["journey_level"] = String(journeyLevel) }
        if let rangeDays { parameters["range_days"] = String(rangeDays) }
        if let ctaType { parameters["cta_type"] = ctaType }
        if let expanded { parameters["expanded"] = expanded ? "true" : "false" }
        return parameters
    }
}

protocol JourneyAnalyticsLogging: Sendable {
    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties)
}

enum JourneyAnalyticsContextBuilder {

    static func snapshot(
        from state: ProgressDashboardState,
        healthConnected: Bool
    ) -> JourneyAnalyticsSnapshot {
        JourneyAnalyticsSnapshot(
            hasProfile: state.hasProfile,
            hasWeightLogs: state.baseline.hasRealWeightEntries,
            usesSyntheticBaseline: state.baseline.usesSyntheticBaselinePoint,
            progressPercentBucket: progressPercentBucket(state.baseline.progressPercent),
            currentStreakBucket: streakBucket(state.streaks.currentLoggingStreakDays),
            unlockedMilestoneCount: state.milestones.unlocked.count,
            healthConnected: healthConnected,
            journeyLevel: state.journeyLevel.currentLevel
        )
    }

    static func properties(from snapshot: JourneyAnalyticsSnapshot) -> JourneyAnalyticsProperties {
        JourneyAnalyticsProperties(
            hasProfile: snapshot.hasProfile,
            hasWeightLogs: snapshot.hasWeightLogs,
            usesSyntheticBaseline: snapshot.usesSyntheticBaseline,
            progressPercentBucket: snapshot.progressPercentBucket,
            currentStreakBucket: snapshot.currentStreakBucket,
            unlockedMilestoneCount: snapshot.unlockedMilestoneCount,
            healthConnected: snapshot.healthConnected,
            journeyLevel: snapshot.journeyLevel
        )
    }

    static func progressPercentBucket(_ percent: Double?) -> String {
        guard let percent, percent > 0 else {
            return JourneyAnalyticsProgressPercentBucket.none.rawValue
        }
        let clamped = min(max(percent, 0), 100)
        switch clamped {
        case 100...:
            return JourneyAnalyticsProgressPercentBucket.complete.rawValue
        case 76..<100:
            return JourneyAnalyticsProgressPercentBucket.nearComplete.rawValue
        case 51..<76:
            return JourneyAnalyticsProgressPercentBucket.strong.rawValue
        case 26..<51:
            return JourneyAnalyticsProgressPercentBucket.mid.rawValue
        case 11..<26:
            return JourneyAnalyticsProgressPercentBucket.building.rawValue
        default:
            return JourneyAnalyticsProgressPercentBucket.low.rawValue
        }
    }

    static func streakBucket(_ days: Int) -> String {
        switch days {
        case 0:
            return JourneyAnalyticsStreakBucket.zero.rawValue
        case 1...3:
            return JourneyAnalyticsStreakBucket.short.rawValue
        case 4...7:
            return JourneyAnalyticsStreakBucket.week.rawValue
        case 8...14:
            return JourneyAnalyticsStreakBucket.twoWeeks.rawValue
        default:
            return JourneyAnalyticsStreakBucket.long.rawValue
        }
    }

    static func ctaType(for cta: JourneyCTA) -> String {
        switch cta {
        case .logWeight: return "log_weight"
        case .logFood: return "log_food"
        case .logWater: return "log_water"
        case .logProtein: return "log_protein"
        case .connectAppleHealth: return "connect_apple_health"
        case .updateGoal: return "update_goal"
        }
    }
}
