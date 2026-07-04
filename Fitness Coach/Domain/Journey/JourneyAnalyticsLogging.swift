//
//  JourneyAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Journey analytics events and safe property bag.
//  Weekly Progress Loop v1 events live in `WeeklyProgressAnalyticsLogging.swift`.
//

import Foundation

enum JourneyAnalyticsEvent: String, Sendable {
    // MARK: Revamp events

    case viewed = "journey_viewed"
    case heroViewed = "journey_hero_viewed"
    case projectionViewed = "journey_projection_viewed"
    case milestoneViewed = "journey_milestone_viewed"
    case milestoneCTATapped = "journey_milestone_cta_tapped"
    case weeklyConsistencyViewed = "journey_weekly_consistency_viewed"
    case storyViewed = "journey_story_viewed"
    case insightsViewed = "journey_insights_viewed"
    case monthlyRecapViewed = "journey_monthly_recap_viewed"
    case chapterViewed = "journey_chapter_viewed"
    case goToTodayTapped = "journey_go_to_today_tapped"
    case weightCTATapped = "journey_weight_cta_tapped"
    case coachCTATapped = "journey_coach_cta_tapped"

    // MARK: Deprecated (pre-revamp — do not emit from Journey UI)

    case screenViewed = "journey_screen_viewed"
    case transformationViewed = "journey_transformation_viewed"
    case goalProjectionViewed = "journey_goal_projection_viewed"
    case weeklyReviewViewed = "journey_weekly_review_viewed"
    case milestoneRailViewed = "journey_milestone_rail_viewed"
    case timelineViewed = "journey_timeline_viewed"
    case startingEmptyStateViewed = "journey_starting_empty_state_viewed"
    case habitInsightViewed = "journey_habit_insight_viewed"
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
    var userStage: String
    var hasProjection: Bool
    var milestoneType: String?
    var chapter: Int?
    var insightCount: Int
    var weeklyCompletionBucket: String

    static let empty = JourneyAnalyticsSnapshot(
        hasProfile: false,
        hasWeightLogs: false,
        usesSyntheticBaseline: false,
        progressPercentBucket: JourneyAnalyticsProgressPercentBucket.none.rawValue,
        currentStreakBucket: JourneyAnalyticsStreakBucket.zero.rawValue,
        unlockedMilestoneCount: 0,
        healthConnected: false,
        userStage: JourneyAnalyticsUserStage.new.rawValue,
        hasProjection: false,
        milestoneType: nil,
        chapter: nil,
        insightCount: 0,
        weeklyCompletionBucket: JourneyAnalyticsWeeklyCompletionBucket.none.rawValue
    )
}

enum JourneyAnalyticsUserStage: String, Sendable {
    case new
    case early
    case active
    case consistent
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

enum JourneyAnalyticsWeeklyCompletionBucket: String, Sendable {
    case none
    case low = "1_2"
    case building = "3_4"
    case strong = "5_6"
    case full = "7"
}

enum JourneyAnalyticsInsightCountBucket: String, Sendable {
    case zero = "0"
    case one = "1"
    case two = "2"
    case three = "3"
}

struct JourneyAnalyticsProperties: Sendable {
    var hasProfile: Bool?
    var hasWeightLogs: Bool?
    var usesSyntheticBaseline: Bool?
    var progressPercentBucket: String?
    var currentStreakBucket: String?
    var unlockedMilestoneCount: Int?
    var healthConnected: Bool?
    var userStage: String?
    var hasProjection: Bool?
    var milestoneType: String?
    var chapter: Int?
    var insightCount: String?
    var weeklyCompletionBucket: String?
    var ctaType: String?

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
        if let userStage { parameters["user_stage"] = userStage }
        if let hasProjection { parameters["has_projection"] = hasProjection ? "true" : "false" }
        if let milestoneType { parameters["milestone_type"] = milestoneType }
        if let chapter { parameters["chapter"] = String(chapter) }
        if let insightCount { parameters["insight_count"] = insightCount }
        if let weeklyCompletionBucket { parameters["weekly_completion_bucket"] = weeklyCompletionBucket }
        if let ctaType { parameters["cta_type"] = ctaType }
        return parameters
    }
}

protocol JourneyAnalyticsLogging: Sendable {
    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties)
}

enum JourneyAnalyticsContextBuilder {

    static func snapshot(
        from state: JourneyDashboardState,
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
            userStage: userStage(from: state).rawValue,
            hasProjection: state.showsGoalProjectionSection,
            milestoneType: milestoneType(from: state),
            chapter: chapter(from: state),
            insightCount: insightCount(from: state),
            weeklyCompletionBucket: weeklyCompletionBucket(from: state)
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
            userStage: snapshot.userStage,
            hasProjection: snapshot.hasProjection,
            milestoneType: snapshot.milestoneType,
            chapter: snapshot.chapter,
            insightCount: insightCountBucket(snapshot.insightCount).rawValue,
            weeklyCompletionBucket: snapshot.weeklyCompletionBucket
        )
    }

    static func userStage(from state: JourneyDashboardState) -> JourneyAnalyticsUserStage {
        if !state.hasMeaningfulJourneyData {
            return .new
        }

        let streak = state.streaks.currentLoggingStreakDays
        let foodDays = state.weeklyReview.foodLoggedDays
        let unlocked = state.milestones.unlocked.count

        if streak >= 8 || (foodDays >= 6 && streak >= 4) {
            return .consistent
        }
        if unlocked >= 2 || streak >= 4 || foodDays >= 4 {
            return .active
        }
        return .early
    }

    static func milestoneType(from state: JourneyDashboardState) -> String? {
        state.milestones.next?.id
    }

    static func chapter(from state: JourneyDashboardState) -> Int? {
        state.showsChapterSection ? state.chapter.chapterNumber : nil
    }

    static func insightCount(from state: JourneyDashboardState) -> Int {
        guard state.showsInsightSection else { return 0 }
        return state.insight.showsLearningState ? 0 : state.insight.insights.count
    }

    static func insightCountBucket(_ count: Int) -> JourneyAnalyticsInsightCountBucket {
        switch min(max(count, 0), 3) {
        case 0: return .zero
        case 1: return .one
        case 2: return .two
        default: return .three
        }
    }

    static func weeklyCompletionBucket(from state: JourneyDashboardState) -> String {
        guard state.showsWeeklyReviewSection else {
            return JourneyAnalyticsWeeklyCompletionBucket.none.rawValue
        }
        return weeklyCompletionBucket(foodLoggedDays: state.weeklyReview.foodLoggedDays)
    }

    static func weeklyCompletionBucket(foodLoggedDays: Int) -> String {
        switch foodLoggedDays {
        case 0:
            return JourneyAnalyticsWeeklyCompletionBucket.none.rawValue
        case 1...2:
            return JourneyAnalyticsWeeklyCompletionBucket.low.rawValue
        case 3...4:
            return JourneyAnalyticsWeeklyCompletionBucket.building.rawValue
        case 5...6:
            return JourneyAnalyticsWeeklyCompletionBucket.strong.rawValue
        default:
            return JourneyAnalyticsWeeklyCompletionBucket.full.rawValue
        }
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

    static func isMilestoneAdvancingCTA(_ cta: JourneyCTA) -> Bool {
        switch cta {
        case .logWeight, .logFood, .logWater, .logProtein:
            return true
        case .connectAppleHealth, .updateGoal:
            return false
        }
    }
}
