//
//  TodayDashboardState.swift
//  Fitness Coach
//
//  Presentation state for the Today tab. Raw nutrition values are mapped from
//  DailyNutritionSummaryBuilder via TodayDashboardNutritionMapper. Section
//  assembly lives in TodayPresentationBuilder.
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
    var goalConnection: TodayGoalConnectionState?

    var mission: TodayMissionState
    var nextBestAction: TodayNextBestActionState
    var quickActions: TodayQuickActionsState
    var meals: TodayMealsState
    var macroHydration: TodayMacroHydrationState
    var activity: TodayActivityState
    var victory: TodayVictoryState
    var smartCoach: TodaySmartCoachState
    var endOfDay: TodayEndOfDayState
}

struct TodayDashboardEmptyContext: Equatable, Sendable {
    var mealsEmptyKind: TodayMealsEmptyKind
    var showsWeightReminder: Bool
}

extension TodayDashboardState {
    var hasMeaningfulLoggedData: Bool {
        !meals.isEmpty
            || macroHydration.waterSummary.consumedMl > 0
            || activity.hasWorkout
            || mission.weightSummary.weightKg != nil
    }
}

// MARK: - Mission

enum TodayMissionPhase: Equatable, Sendable {
    case brandNewUser
    case noMealsLogged
    case inProgress
    case targetMet
    case overTarget
}

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
    var phase: TodayMissionPhase
    var status: TodayMissionStatus
    var sectionTitle: String
    var primaryMetricLabel: String
    var primaryMetricValue: String
    var statusLine: String
    var progress: Double
    var showsLogMealCTA: Bool
    var accessibilityLabel: String
    var calorieSummary: CalorieSummary
    var weightSummary: TodayWeightSummary
    var goalProgress: TodayGoalProgressState?
}

// MARK: - Next best action

enum TodayNextBestActionCTA: Equatable, Sendable {
    case logMeal(String?)
    case scanFood
    case addWater(amountMl: Int)
    case logWeight
    case openHealth
    case reviewToday
    case none
}

enum TodayNextBestActionReason: Equatable, Sendable {
    case logFirstMeal
    case logMissedMeal(MealType)
    case eatProtein
    case addWater
    case logWeight
    case connectAppleHealth
    case reviewToday
    case onTrack
}

struct TodayNextBestActionState: Equatable {
    var sectionTitle: String
    var title: String
    var subtitle: String?
    var reason: TodayNextBestActionReason
    var primaryCTA: TodayNextBestActionCTA
    var secondaryCTAs: [TodayNextBestActionCTA]
    var accessibilityLabel: String
}

// MARK: - Quick actions

struct TodayQuickActionsState: Equatable {
    var sectionTitle: String
    var items: [TodayQuickActionMenuItem]
}

// MARK: - Meals

enum TodayMealsPhase: Equatable, Sendable {
    case brandNewUser
    case noMealsToday
    case hasMeals
}

struct TodayMealsState: Equatable {
    var phase: TodayMealsPhase
    var sectionTitle: String
    var entries: [FoodEntry]
    var entryCount: Int
    var emptyTitle: String?
    var emptyBody: String?
    var emptyActionTitle: String?

    var isEmpty: Bool { entries.isEmpty }
}

// MARK: - Macro + hydration

enum TodayMacroHydrationFocus: Equatable, Sendable {
    case onTrack
    case proteinBehind
    case waterBehind
    case bothBehind
}

struct TodayMacroHydrationState: Equatable {
    var focus: TodayMacroHydrationFocus
    var sectionTitle: String
    var guidanceLine: String?
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
}

// MARK: - Activity

enum TodayActivityPhase: Equatable, Sendable {
    case healthUnavailable
    case disconnected
    case empty
    case hasData
    case workoutCompleted
}

struct TodayActivityState: Equatable {
    var phase: TodayActivityPhase
    var sectionTitle: String
    var legacyWorkoutSummary: TodayWorkoutSummary
    var trainingIntegration: TrainingIntegrationState
    var trainingDataSource: TrainingDataSource
    var appleHealthWorkoutCount: Int?
    var stepsToday: Int?
    var stepGoalAssumption: Int?
    var displayLine: String
    var showsConnectCTA: Bool

    var hasWorkout: Bool {
        legacyWorkoutSummary.hasWorkout || (appleHealthWorkoutCount ?? 0) > 0
    }
}

struct TodayActivityContext: Equatable, Sendable {
    var trainingIntegration: TrainingIntegrationState
    var trainingDataSource: TrainingDataSource
    var appleHealthWorkoutCount: Int?
    var stepsToday: Int?

    static let `default` = TodayActivityContext(
        trainingIntegration: .connected,
        trainingDataSource: .appleHealth,
        appleHealthWorkoutCount: nil,
        stepsToday: nil
    )
}

// MARK: - Victory

struct TodayVictoryState: Equatable {
    var isVisible: Bool
    var message: String
}

// MARK: - Smart coach (contextual)

enum TodaySmartCoachContext: Equatable, Sendable {
    case logFirstMeal
    case proteinBehind
    case waterBehind
    case overTarget
    case workoutCompleted
}

struct TodaySmartCoachState: Equatable {
    var isVisible: Bool
    var context: TodaySmartCoachContext?
    var message: String
    var coachPrefill: String?
}

// MARK: - End of day

struct TodayEndOfDayState: Equatable {
    var isVisible: Bool
    var message: String
    var suggestsReview: Bool
    var reviewCTATitle: String?
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

// MARK: - Legacy typealiases (migration)

typealias NextBestActionCTA = TodayNextBestActionCTA
typealias NextBestActionReason = TodayNextBestActionReason
typealias NextBestActionState = TodayNextBestActionState
typealias ActivityTodayState = TodayActivityState
typealias MealStatusState = TodayMealsState
typealias MacroBalanceState = TodayMacroHydrationState
