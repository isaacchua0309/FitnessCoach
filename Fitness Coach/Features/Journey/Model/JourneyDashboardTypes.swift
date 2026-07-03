//
//  JourneyDashboardTypes.swift
//  Fitness Coach
//
//  Forma — Unified immutable state for the Journey “fitness story” dashboard.
//

import Foundation

// MARK: - Goal direction

enum JourneyGoalDirection: Equatable, Sendable {
    case lose
    case gain
    case maintain

    static func resolve(startWeightKg: Double?, goalWeightKg: Double?) -> JourneyGoalDirection {
        guard let startWeightKg, let goalWeightKg else { return .maintain }
        if abs(startWeightKg - goalWeightKg) <= 0.1 { return .maintain }
        return goalWeightKg < startWeightKg ? .lose : .gain
    }
}

// MARK: - Baseline

struct JourneyBaseline: Equatable {
    var startWeightKg: Double?
    var startDate: Date
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var goalDirection: JourneyGoalDirection
    var totalChangeKg: Double?
    var remainingChangeKg: Double?
    var progressPercent: Double?
    var estimatedCompletionDate: Date?
    var estimatedCompletionMonthLabel: String?
    var hasRealWeightEntries: Bool
    /// True when `startWeightKg` comes from profile onboarding weight, not earliest log.
    var usesSyntheticBaselinePoint: Bool
    /// Profile/onboarding anchor used for chart lead-in when it differs from earliest log.
    var onboardingBaselineWeightKg: Double?
    /// Journey weight trend input (synthetic + logged), sorted by date.
    var chartPoints: [WeightChartPoint]
    /// Chart is available with onboarding baseline — no two-log gate.
    var showsWeightChart: Bool
}

// MARK: - Transformation hero

struct JourneyStreakChipState: Equatable {
    var isVisible: Bool
    var days: Int
    var label: String

    static let hidden = JourneyStreakChipState(isVisible: false, days: 0, label: "")
}

struct JourneyTransformationHeroState: Equatable {
    var headlineCopy: String
    var changeValueCopy: String
    var emotionalStatusLabel: String
    /// Normalized 0...1 fill for the SwiftUI progress bar (includes a visible sliver at 0%).
    var progressBarFill: Double
    var progressLabel: String
    var progressBarAccessibilityValue: String
    var startedWeightCopy: String
    var todayWeightCopy: String
    var goalWeightCopy: String
    var startedFootnote: String?
    var paceForecastText: String
    var streakChip: JourneyStreakChipState
    var usesSyntheticBaseline: Bool
    var showsUpdateGoalCTA: Bool
    var accessibilitySummary: String
}

// MARK: - Streaks

struct JourneyStreakState: Equatable {
    var currentLoggingStreakDays: Int
    var longestLoggingStreakDays: Int
    var currentProteinStreakDays: Int
    var currentWaterStreakDays: Int
    var currentTrainingStreakWeeks: Int?
    var isTodayLogged: Bool
    var heroStreakChip: JourneyStreakChipState
    var weeklyConsistencyHeadline: String
    var weeklyConsistencyDetail: String?
    var keepStreakAliveCopy: String?
}

// MARK: - Weekly review

struct JourneyWeeklyReviewState: Equatable {
    var foodLoggedDays: Int
    var foodLoggedDaysTotal: Int
    var proteinGoalDays: Int
    var proteinGoalDaysTotal: Int
    var waterGoalDays: Int
    var waterGoalDaysTotal: Int
    var trainingDays: Int
    var expectedTrainingDays: Int
    var training: JourneyWeeklyTrainingStatus
    var weightDeltaThisWeekKg: Double?
    var calorieAdherenceDays: Int
    var calorieAdherenceDaysTotal: Int
    var weekSummaryCopy: String
    var rows: [JourneyWeeklyReviewRow]
    var weekOverWeekDetail: String?
    var consistencyHeadline: String?
    var consistencyDetail: String?
}

struct JourneyWeeklyReviewRow: Equatable, Identifiable {
    var id: String
    var icon: String
    var title: String
    var value: String
    var detail: String?
    var winScore: Double
}

struct JourneyWeeklyReviewPreviousWeek: Equatable {
    var foodLoggedDays: Int
    var proteinGoalDays: Int
    var waterGoalDays: Int
    var calorieAdherenceDays: Int
    var trainingDays: Int
    var weightDeltaKg: Double?

    var hasComparableData: Bool {
        foodLoggedDays > 0
            || proteinGoalDays > 0
            || waterGoalDays > 0
            || calorieAdherenceDays > 0
            || trainingDays > 0
            || weightDeltaKg != nil
    }
}

// MARK: - Milestones

enum JourneyMilestoneCategory: Equatable, Sendable {
    case weightProgress
    case foodLogging
    case proteinConsistency
    case waterConsistency
    case trainingConsistency
    case streaks
    case onboarding
}

enum JourneyMilestoneStatus: Equatable, Sendable {
    case completed
    case current
    case upcoming
}

struct JourneyMilestone: Identifiable, Equatable {
    var id: String
    var title: String
    var category: JourneyMilestoneCategory
    var status: JourneyMilestoneStatus
    var progressFraction: Double?
    var weightKg: Double?

    init(
        id: String,
        title: String,
        category: JourneyMilestoneCategory = .weightProgress,
        status: JourneyMilestoneStatus,
        progressFraction: Double? = nil,
        weightKg: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.status = status
        self.progressFraction = progressFraction
        self.weightKg = weightKg
    }
}

struct JourneyMilestonesState: Equatable {
    var unlocked: [JourneyMilestone]
    var upcoming: [JourneyMilestone]
    var next: JourneyMilestone?
    var nextProgressFraction: Double?
    var items: [JourneyMilestone]

    static let empty = JourneyMilestonesState(
        unlocked: [],
        upcoming: [],
        next: nil,
        nextProgressFraction: nil,
        items: []
    )
}

// MARK: - Story timeline

enum JourneyTimelineEventType: Equatable, Sendable {
    case onboardingStarted
    case firstMealLogged
    case firstWaterLogged
    case firstWeightLogged
    case firstWorkoutWeek
    case firstWeekComplete
    case firstKgTowardGoal
    case calorieGoalFiveDays
    case proteinGoalFiveDays
    case thirtyMealsLogged
    case halfwayToGoal
    case longestStreakAchieved
    case monthlyRecapCompleted
}

struct JourneyTimelineEvent: Identifiable, Equatable {
    var id: String
    var date: Date
    var type: JourneyTimelineEventType
    var title: String
    var subtitle: String?
    var icon: String
    var isMajorEvent: Bool
}

struct JourneyStoryTimelineState: Equatable {
    var events: [JourneyTimelineEvent]
    var displayEvents: [JourneyTimelineEvent]
    var emptyStateMessage: String?

    static let empty = JourneyStoryTimelineState(
        events: [],
        displayEvents: [],
        emptyStateMessage: nil
    )
}

// MARK: - Weight chart

enum JourneyWeightChartPointLabel: Equatable, Sendable {
    case onboarding
    case started
    case logged
}

struct WeightChartPoint: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var isSynthetic: Bool
    var pointLabel: JourneyWeightChartPointLabel?

    init(
        id: UUID = UUID(),
        date: Date,
        weightKg: Double,
        isSynthetic: Bool = false,
        pointLabel: JourneyWeightChartPointLabel? = nil
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.isSynthetic = isSynthetic
        self.pointLabel = pointLabel
    }
}

extension JourneyWeightChartPointLabel {
    var displayTitle: String {
        switch self {
        case .onboarding:
            return "Onboarding"
        case .started:
            return "Started"
        case .logged:
            return ""
        }
    }
}

// MARK: - Analytics summaries

struct ProgressNutritionSummary: Equatable {
    var loggedDays: Int
    var averageCalories: Int?
    var averageProtein: Double?
    var averageCarbs: Double?
    var averageFat: Double?
    var averageFiber: Double?
}

struct ProgressWaterSummary: Equatable {
    var loggedDays: Int
    var averageWaterMl: Int?
    var averageWaterTargetMl: Int?
    var consistencyPercent: Double?
}

struct ProgressWorkoutSummary: Equatable {
    var workoutCount: Int
    var workoutDays: Int?
    var totalEstimatedCaloriesBurned: Int
    var averageWorkoutsPerWeek: Double
    var averageDurationMinutes: Int?
    var isFromAppleHealth: Bool = false
}

/// Lightweight weight summary for Journey builders (no spreadsheet UI).
struct ProgressWeightSummary: Equatable {
    var latestWeightKg: Double?
    var changeKg: Double?
    var direction: WeightTrendDirection
    var hasSuddenSpike: Bool
}
