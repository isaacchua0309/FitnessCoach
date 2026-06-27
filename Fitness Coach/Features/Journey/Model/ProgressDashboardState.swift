//
//  ProgressDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Journey transformation state.
//

import Foundation

struct ProgressDashboardState: Equatable {
    var selectedRangeDays: Int
    var transformation: JourneyTransformationState
    var milestones: [JourneyMilestone]
    var nextCheckpointKg: Double?
    var sectionVisibility: JourneySectionVisibility
    var weeklySnapshot: JourneyWeeklySnapshot
    var coachInsights: [JourneyCoachInsight]
    var consistencyCalendar: JourneyConsistencyCalendar
    var achievements: [JourneyAchievement]
    var weightTrend: JourneyWeightTrendState
    var analytics: ProgressAnalyticsDetail
    var hasProfile: Bool
}

struct JourneySectionVisibility: Equatable {
    /// Weight trend chart requires at least two logged weights.
    var showsWeightTrendSection: Bool
    /// Standalone milestone rail — hidden in current Journey polish pass.
    var showsMilestonesSection: Bool
}

// MARK: Transformation Hero

struct JourneyTransformationState: Equatable {
    var goalTitle: String
    var startedLabel: String
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var progressPercent: Double?
    var estimatedCompletionLabel: String?
    var currentPhase: String
    var coachInsight: String
}

// MARK: Milestones

enum JourneyMilestoneStatus: Equatable, Sendable {
    case completed
    case current
    case upcoming
}

struct JourneyMilestone: Identifiable, Equatable {
    var id: String
    var weightKg: Double
    var status: JourneyMilestoneStatus
}

// MARK: Weekly Snapshot

struct JourneyWeeklySnapshot: Equatable {
    var training: JourneyWeeklyTrainingStatus
    var proteinDaysAchieved: Int
    var proteinDaysTotal: Int
    var waterDaysAchieved: Int
    var waterDaysTotal: Int
    var averageCalorieDeficit: Int?
}

// MARK: Coach Insights

struct JourneyCoachInsight: Identifiable, Equatable {
    var id: String
    var message: String
}

// MARK: Consistency Calendar

struct JourneyConsistencyCalendar: Equatable {
    var monthTitle: String
    var weekdaySymbols: [String]
    var days: [JourneyCalendarDay]
    var completedCount: Int
    /// Unique logged days in the maturity window (meals, water, weight, or workouts).
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

// MARK: Achievements

struct JourneyAchievement: Identifiable, Equatable {
    var id: String
    var title: String
    var isUnlocked: Bool
}

// MARK: Weight Trend

struct JourneyWeightTrendState: Equatable {
    var chartPoints: [WeightChartPoint]
    var interpretation: String
}

struct WeightChartPoint: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var weightKg: Double

    init(id: UUID = UUID(), date: Date, weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: Detailed Analytics

struct ProgressAnalyticsDetail: Equatable {
    var nutritionSummary: ProgressNutritionSummary
    var waterSummary: ProgressWaterSummary
    var workoutSummary: ProgressWorkoutSummary?
    var weightChartPoints: [WeightChartPoint]
}

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
