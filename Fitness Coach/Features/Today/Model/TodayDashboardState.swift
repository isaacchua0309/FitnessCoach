//
//  TodayDashboardState.swift
//  Fitness Coach
//
//  Mission Control view state for the Today dashboard.
//
//  Nutrition values are mapped from DailyNutritionSummaryBuilder via
//  TodayDashboardNutritionMapper. Section assembly lives in
//  TodayMissionControlStateBuilder.
//

import Foundation

enum TodayViewState: Equatable {
    case loading
    case loaded(TodayDashboardState)
    case empty
    case error(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

// MARK: - Dashboard root

struct TodayDashboardState: Equatable {
    var date: Date
    var hasDailyLog: Bool
    var emptyContext: TodayDashboardEmptyContext
    var mission: TodayMissionState
    var goalConnection: TodayGoalConnectionState?
    var nextBestAction: NextBestActionState
    var meals: MealStatusState
    var activity: ActivityTodayState
    var macroBalance: MacroBalanceState
    var momentum: TodayMomentumState
    var dailyScorecard: TodayDailySummaryScorecardState
    var dailySummary: DailySummaryState
    var aiCoachTip: AICoachTipState
}

struct TodayDashboardEmptyContext: Equatable, Sendable {
    var mealsEmptyKind: TodayMealsEmptyKind
    var showsWeightReminder: Bool
}

extension TodayDashboardState {
    /// Enough logged data to make a daily review meaningful.
    var hasMeaningfulLoggedData: Bool {
        !meals.isEmpty
            || macroBalance.waterSummary.consumedMl > 0
            || activity.legacyWorkoutSummary.hasWorkout
            || mission.weightSummary.weightKg != nil
    }
}

// MARK: - Section 1: Today's Mission

enum TodayMissionStatus: Equatable, Sendable {
    case onTrack
    case needsFocus
    case overBudget
}

struct TodayGoalProgressState: Equatable, Sendable {
    var currentWeightKg: Double
    var goalWeightKg: Double
    var kgToGo: Double
    var direction: JourneyGoalDirection
}

struct TodayMissionState: Equatable {
    var status: TodayMissionStatus
    var calorieSummary: CalorieSummary
    var weightSummary: TodayWeightSummary
    var goalProgress: TodayGoalProgressState?
    var focusMessage: String
    var proteinRemainingGrams: Double
}

// MARK: - Section 2: Next Best Action

enum NextBestActionCTA: Equatable, Sendable {
    case logMeal(String?)
    case scanFood
    case addWater(amountMl: Int)
    case logWeight
    case openHealth
    case reviewToday
    case none
}

enum NextBestActionReason: Equatable, Sendable {
    case logFirstMeal
    case logMissedMeal(MealType)
    case eatProtein
    case addWater
    case logWeight
    case connectAppleHealth
    case reviewToday
    case onTrack
}

struct NextBestActionState: Equatable {
    var title: String
    var subtitle: String?
    var reason: NextBestActionReason
    var primaryCTA: NextBestActionCTA
    var secondaryCTAs: [NextBestActionCTA]
}

// MARK: - Section 3: Meals

struct MealStatusState: Equatable {
    var entries: [FoodEntry]
    var entryCount: Int
    var isEmpty: Bool
}

// MARK: - Section 4: Activity

struct TodayActivityContext: Equatable, Sendable {
    var trainingIntegration: TrainingIntegrationState
    var trainingDataSource: TrainingDataSource
    var appleHealthWorkoutCount: Int?
    var stepsToday: Int?
    var weeklyWorkoutCount: Int?

    static let `default` = TodayActivityContext(
        trainingIntegration: .connected,
        trainingDataSource: .appleHealth,
        appleHealthWorkoutCount: nil,
        stepsToday: nil,
        weeklyWorkoutCount: nil
    )
}

struct ActivityTodayState: Equatable {
    var legacyWorkoutSummary: TodayWorkoutSummary
    var trainingIntegration: TrainingIntegrationState
    var trainingDataSource: TrainingDataSource
    var appleHealthWorkoutCount: Int?
    var stepsToday: Int?
    var weeklyWorkoutCount: Int?
    var stepGoalAssumption: Int?
    var trainingFrequencyPerWeek: Int?
    var displayLine: String
    var showsConnectCTA: Bool
}

// MARK: - Section 5: Macro Balance

struct MacroBalanceState: Equatable {
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
}

// MARK: - Section 6: Momentum

struct TodayMomentumState: Equatable {
    var streaks: StreakSummary
    var weekLoggedDays: Int
    static let weekTotalDays = 7
}

// MARK: - Section 7: Daily Summary

struct DailySummaryState: Equatable {
    var greeting: String
    var priorities: [String]
    var userName: String?
    var dailyReview: DailyReview?
}

// MARK: - Section 8: AI Coach Tip

struct AICoachTipState: Equatable {
    var message: String
    var coachPrefill: String?
}

// MARK: - Shared nutrition summaries

struct CalorieSummary: Equatable {
    var consumed: Int
    var target: Int
    var remaining: Int
    var progress: Double
    var isOverTarget: Bool
}

struct MacroSummary: Equatable {
    var protein: MacroProgress
    var carbs: MacroProgress
    var fat: MacroProgress
}

struct MacroProgress: Equatable {
    var consumed: Double
    var target: Double
    var remaining: Double
    var progress: Double
}

struct WaterSummary: Equatable {
    var consumedMl: Int
    var targetMl: Int
    var remainingMl: Int
    var progress: Double
}

struct TodayWeightSummary: Equatable {
    var weightKg: Double?
    var displayText: String
}

struct TodayWorkoutSummary: Equatable {
    var workoutCaloriesBurned: Int
    var workoutCount: Int
    var hasWorkout: Bool
}
