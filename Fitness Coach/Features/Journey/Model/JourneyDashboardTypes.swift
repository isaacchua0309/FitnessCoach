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
    var progressBarPercent: Double
    var progressLabel: String
    var progressBarAccessibilityValue: String
    var startedWeightCopy: String
    var todayWeightCopy: String
    var goalWeightCopy: String
    var startedFootnote: String?
    var paceForecastText: String
    var streakChip: JourneyStreakChipState
    var usesSyntheticBaseline: Bool
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
    var habitInsightStreakCopy: String
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
    var strongestPositiveSignal: String
    var weakestSignal: String
    var weekSummaryCopy: String
    var averageCalorieDeficit: Int?
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
    var progressPercent: Double
    var items: [JourneyMilestone]

    static let empty = JourneyMilestonesState(
        unlocked: [],
        upcoming: [],
        next: nil,
        nextProgressFraction: nil,
        progressPercent: 0,
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

// MARK: - Habit insights

enum JourneyHabitKind: Equatable, Sendable, CaseIterable {
    case foodLogging
    case protein
    case water
    case calorieAdherence
    case training
    case weightLogging
    case weekendLogging
}

struct JourneyHabitInsightsState: Equatable {
    var isUnlocked: Bool
    var lockedMessage: String?

    var strongestHabitLabel: String
    var strongestScorePercent: Int
    var strongestQualitative: String?

    var weakestHabitLabel: String
    var weakestScorePercent: Int
    var weakestScorePrefix: String?

    var suggestedNextAction: String

    static let locked = JourneyHabitInsightsState(
        isUnlocked: false,
        lockedMessage: FormaProductCopy.Journey.HabitInsights.lockedBody,
        strongestHabitLabel: "",
        strongestScorePercent: 0,
        strongestQualitative: nil,
        weakestHabitLabel: "",
        weakestScorePercent: 0,
        weakestScorePrefix: nil,
        suggestedNextAction: ""
    )
}

// MARK: - Progress attribution

enum JourneyProgressAttributionConfidence: Equatable, Sendable {
    case low
    case medium
    case high
}

struct JourneyProgressAttributionState: Equatable {
    var primaryReasonTitle: String
    var primaryReasonDetail: String
    var supportingReasons: [String]
    var confidence: JourneyProgressAttributionConfidence

    static let insufficientData = JourneyProgressAttributionState(
        primaryReasonTitle: FormaProductCopy.Journey.WhyProgress.insufficientTitle,
        primaryReasonDetail: FormaProductCopy.Journey.WhyProgress.insufficientDetail,
        supportingReasons: [],
        confidence: .low
    )
}

// MARK: - Before vs today

struct JourneyBeforeTodayState: Equatable {
    var startedWeightKg: Double?
    var currentWeightKg: Double?
    var startingMaintenanceCaloriesKcal: Int?
    var currentMaintenanceCaloriesKcal: Int?
    var startingTargetCaloriesKcal: Int?
    var currentTargetCaloriesKcal: Int?
    var goalWeightKg: Double?
    var daysOnJourney: Int
    var showsMaintenanceRow: Bool
    var showsTargetRow: Bool
    var showsAdaptedTargetCopy: Bool
}

// MARK: - Personal records

struct JourneyPersonalRecord: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
    var subtitle: String?
    var periodLabel: String?
    var isActive: Bool
    var isEarlyRecord: Bool
}

struct JourneyPersonalRecordsState: Equatable {
    var isUnlocked: Bool
    var lockedMessage: String?
    var records: [JourneyPersonalRecord]

    var displayRecords: [JourneyPersonalRecord] {
        records.filter(\.isActive)
    }

    static let locked = JourneyPersonalRecordsState(
        isUnlocked: false,
        lockedMessage: FormaProductCopy.Journey.PersonalRecords.lockedBody,
        records: []
    )
}

// MARK: - Monthly recap

struct JourneyMonthlyRecapMetricRow: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
}

struct JourneyMonthlyRecapState: Equatable {
    var sectionTitle: String
    var isComplete: Bool
    var buildingMessage: String?
    var monthLabel: String
    var monthWeightDeltaKg: Double?
    var calorieAdherencePercent: Double?
    var proteinAdherencePercent: Double?
    var waterAdherencePercent: Double?
    var trainingSessions: Int?
    var showsTrainingRow: Bool
    var loggedDays: Int
    var bestHabitCopy: String?
    var summaryCopy: String
    var rows: [JourneyMonthlyRecapMetricRow]
    var calendar: JourneyConsistencyCalendar
}

// MARK: - Journey level / XP

struct JourneyLevelState: Equatable {
    var currentLevel: Int
    var levelTitle: String
    var currentXP: Int
    var xpRequiredForNextLevel: Int
    var totalXP: Int
    var progressPercent: Double
    var xpEarnedExplanation: String
    var hasData: Bool
}

// MARK: - Detailed analytics

struct JourneyDetailedAnalyticsState: Equatable {
    var isCollapsedByDefault: Bool
    var nutritionSummary: ProgressNutritionSummary
    var waterSummary: ProgressWaterSummary
    var workoutSummary: ProgressWorkoutSummary?
    var weightChartPoints: [WeightChartPoint]
    var weightTrendInterpretation: String
    var showsWeightChart: Bool
}

// MARK: - Consistency calendar (shared by monthly recap & habit insights)

struct JourneyConsistencyCalendar: Equatable {
    var monthTitle: String
    var weekdaySymbols: [String]
    var days: [JourneyCalendarDay]
    var completedCount: Int
    var totalLoggedDays: Int

    var displayMode: JourneyConsistencyDisplayMode {
        if totalLoggedDays == 0 {
            return .momentumEmpty
        }
        if totalLoggedDays < JourneyLayout.minimumLoggedDaysForCalendar {
            return .consistencySummary
        }
        return .fullCalendar
    }

    static let empty = JourneyConsistencyCalendar(
        monthTitle: "",
        weekdaySymbols: [],
        days: [],
        completedCount: 0,
        totalLoggedDays: 0
    )
}

enum JourneyConsistencyDisplayMode: Equatable {
    case momentumEmpty
    case consistencySummary
    case fullCalendar
}

struct JourneyCalendarDay: Identifiable, Equatable {
    var id: String
    var dayNumber: Int?
    var isCompleted: Bool
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
