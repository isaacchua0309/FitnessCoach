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
    case pendingAccountRestore(message: String)
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
    var yesterdayReview: TodayYesterdayReviewState
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
    var primaryKind: TodayMissionPrimaryKind
    var primaryValue: String
    var goalLine: String
    var consumedLine: String
    var proteinRemainingLine: String
    var statusLine: String
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
    case logWorkout
    case logWeight
    case openHealth
    case reviewToday
    case none
}

enum TodayNextBestActionReason: Equatable, Sendable {
    case logBreakfast
    case logFirstMeal
    case eatProtein
    case addWater
    case completeWorkout
    case keepDinnerLight
    case focusHydrationRecovery
    case allTargetsMet
}

struct TodayNextBestActionState: Equatable {
    var sectionTitle: String
    var title: String
    var subtitle: String?
    var reason: TodayNextBestActionReason
    var primaryCTA: TodayNextBestActionCTA
    var secondaryCTAs: [TodayNextBestActionCTA]
    var accessibilityLabel: String

    init(
        sectionTitle: String,
        title: String,
        subtitle: String?,
        reason: TodayNextBestActionReason,
        primaryCTA: TodayNextBestActionCTA,
        secondaryCTAs: [TodayNextBestActionCTA],
        accessibilityLabel: String
    ) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.subtitle = subtitle
        self.reason = reason
        self.primaryCTA = primaryCTA
        self.secondaryCTAs = secondaryCTAs
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        title: String,
        subtitle: String?,
        reason: TodayNextBestActionReason,
        primaryCTA: TodayNextBestActionCTA,
        secondaryCTAs: [TodayNextBestActionCTA] = []
    ) {
        let provisional = TodayNextBestActionState(
            sectionTitle: FormaProductCopy.Today.NextAction.sectionTitle,
            title: title,
            subtitle: subtitle,
            reason: reason,
            primaryCTA: primaryCTA,
            secondaryCTAs: secondaryCTAs,
            accessibilityLabel: ""
        )
        let display = TodayNextActionFormatting.displayModel(for: provisional)
        self.init(
            sectionTitle: display.sectionTitle,
            title: title,
            subtitle: subtitle,
            reason: reason,
            primaryCTA: primaryCTA,
            secondaryCTAs: secondaryCTAs,
            accessibilityLabel: display.accessibilityLabel
        )
    }
}

// MARK: - Quick actions

struct TodayQuickActionsState: Equatable {
    var sectionTitle: String
    var showsScanMeal: Bool
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
    var showsConnectCTA: Bool
    var date: Date
    var trainingFrequencyPerWeek: Int

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
    var kind: TodayVictoryKind
    var message: String

    var isVisible: Bool {
        kind != .hidden
    }

    static let hidden = TodayVictoryState(kind: .hidden, message: "")
}

// MARK: - Smart coach (contextual)

enum TodaySmartCoachContext: Equatable, Sendable {
    case hidden
    case proteinBehind
    case waterBehind
    case caloriesCloseToTarget
    case caloriesExceeded
    case workoutRecovery
    case endOfDayIncomplete
}

struct TodaySmartCoachState: Equatable {
    var context: TodaySmartCoachContext
    var message: String
    var coachPrefill: String?
    var coachActionTitle: String?

    var isVisible: Bool {
        context != .hidden
    }

    var accessibilityLabel: String {
        [message, coachActionTitle].compactMap { $0 }.joined(separator: ". ")
    }

    static let hidden = TodaySmartCoachState(
        context: .hidden,
        message: "",
        coachPrefill: nil,
        coachActionTitle: nil
    )
}

// MARK: - Yesterday review

enum TodayYesterdayReviewCTA: Equatable, Sendable {
    case viewReview
    case generateReview
}

struct TodayYesterdayReviewState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var previewLines: [String]
    var actionTitle: String
    var actionHint: String
    var cta: TodayYesterdayReviewCTA
    var reviewDate: Date
    var review: DailyReview?
    var analyticsFoodEntryCount: Int
    var accessibilityLabel: String

    static let hidden = TodayYesterdayReviewState(
        isVisible: false,
        sectionTitle: "",
        previewLines: [],
        actionTitle: "",
        actionHint: "",
        cta: .viewReview,
        reviewDate: .distantPast,
        review: nil,
        analyticsFoodEntryCount: 0,
        accessibilityLabel: ""
    )
}

// MARK: - End of day

struct TodayEndOfDayState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var overallMessage: String?
    var noLogsMessage: String?
    var rows: [TodayEndOfDayRowState]
    var journeyActionTitle: String
    var journeyActionHint: String
    var accessibilityLabel: String

    static let hidden = TodayEndOfDayState(
        isVisible: false,
        sectionTitle: "",
        overallMessage: nil,
        noLogsMessage: nil,
        rows: [],
        journeyActionTitle: "",
        journeyActionHint: "",
        accessibilityLabel: ""
    )
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
