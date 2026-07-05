//
//  TodayHealthIntelligencePresentationState.swift
//  Fitness Coach
//
//  Forma — Presentation models mapping Health Intelligence into Today-friendly cards.
//  No HealthKit or repository types; snapshot-derived copy only.
//

import Foundation

// MARK: - Section root

struct TodayHealthIntelligenceSectionState: Equatable, Sendable {
    var recoveryCard: TodayRecoveryCardState
    var dailyMission: TodayDailyMissionState
    var nextBestAction: TodayHealthNextBestActionState
    var workoutCard: TodayHealthWorkoutCardState?
    var adaptiveNutritionCard: TodayAdaptiveNutritionCardState?
    var isLoading: Bool
    var fallbackMessage: String?
    var uiState: HealthIntelligenceUIState?
    var staleDataLabel: String?

    var isVisible: Bool {
        !isLoading || fallbackMessage != nil
    }
}

// MARK: - Recovery

enum TodayRecoveryCardPhase: Equatable, Sendable {
    case ready
    case moderate
    case low
    case unknown
    case limitedEstimate
}

struct TodayRecoveryCardState: Equatable, Sendable {
    var phase: TodayRecoveryCardPhase
    var sectionTitle: String
    var title: String
    var subtitle: String?
    var trainingGuidance: String?
    var nutritionGuidance: String?
    var confidenceNote: String?
    var missingDataNote: String?
    var staleDataLabel: String?
    var accessibilityLabel: String

    static let loading = TodayRecoveryCardState(
        phase: .unknown,
        sectionTitle: FormaProductCopy.Today.HealthIntelligence.Recovery.sectionTitle,
        title: FormaProductCopy.Today.HealthIntelligence.loadingTitle,
        subtitle: FormaProductCopy.Today.HealthIntelligence.loadingSubtitle,
        trainingGuidance: nil,
        nutritionGuidance: nil,
        confidenceNote: nil,
        missingDataNote: nil,
        staleDataLabel: nil,
        accessibilityLabel: FormaProductCopy.Today.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Daily mission

struct TodayDailyMissionState: Equatable, Sendable {
    var sectionTitle: String
    var headline: String
    var detailLines: [String]
    var focusSummary: String?
    var accessibilityLabel: String

    static let loading = TodayDailyMissionState(
        sectionTitle: FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle,
        headline: FormaProductCopy.Today.HealthIntelligence.loadingTitle,
        detailLines: [FormaProductCopy.Today.HealthIntelligence.loadingSubtitle],
        focusSummary: nil,
        accessibilityLabel: FormaProductCopy.Today.HealthIntelligence.loadingAccessibilityLabel
    )
}

// MARK: - Next best action (Health Intelligence)

struct TodayHealthNextBestActionState: Equatable, Sendable {
    var isVisible: Bool
    var sectionTitle: String
    var title: String
    var message: String?
    var ctaTitle: String?
    var destination: TodayHealthNextBestActionDestination
    var accessibilityLabel: String

    static let hidden = TodayHealthNextBestActionState(
        isVisible: false,
        sectionTitle: FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
        title: "",
        message: nil,
        ctaTitle: nil,
        destination: .none,
        accessibilityLabel: ""
    )

    static let loading = TodayHealthNextBestActionState(
        isVisible: false,
        sectionTitle: FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle,
        title: "",
        message: nil,
        ctaTitle: nil,
        destination: .none,
        accessibilityLabel: FormaProductCopy.Today.HealthIntelligence.loadingAccessibilityLabel
    )
}

enum TodayHealthNextBestActionDestination: Equatable, Sendable {
    case logMeal
    case addWater
    case askCoach
    case viewRecovery
    case logWeight
    case connectHealth
    case refreshHealthData
    case manageHealthPermissions
    case none
}

// MARK: - Workout

enum TodayHealthWorkoutCardPhase: Equatable, Sendable {
    case completed
    case empty
    case plannedRest
    case unknown
}

struct TodayHealthWorkoutCardState: Equatable, Sendable {
    var phase: TodayHealthWorkoutCardPhase
    var sectionTitle: String
    var title: String
    var subtitle: String?
    var nutritionTip: String?
    var hydrationTip: String?
    var accessibilityLabel: String
}

// MARK: - Adaptive nutrition

struct TodayAdaptiveNutritionCardState: Equatable, Sendable {
    var isVisible: Bool
    var sectionTitle: String
    var title: String
    var subtitle: String?
    var proteinGuidance: String?
    var calorieGuidance: String?
    var waterGuidance: String?
    var confidenceNote: String?
    var accessibilityLabel: String

    static let hidden = TodayAdaptiveNutritionCardState(
        isVisible: false,
        sectionTitle: FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.sectionTitle,
        title: "",
        subtitle: nil,
        proteinGuidance: nil,
        calorieGuidance: nil,
        waterGuidance: nil,
        confidenceNote: nil,
        accessibilityLabel: ""
    )
}

// MARK: - Nutrition progress bridge (Today summaries → daily mission)

struct TodayHealthIntelligenceNutritionProgress: Equatable, Sendable {
    var calorieRemaining: Int?
    var proteinRemainingGrams: Double?
    var waterRemainingMl: Int?
    var hasCalorieTarget: Bool
    var hasProteinTarget: Bool
    var hasWaterTarget: Bool

    static let unavailable = TodayHealthIntelligenceNutritionProgress(
        calorieRemaining: nil,
        proteinRemainingGrams: nil,
        waterRemainingMl: nil,
        hasCalorieTarget: false,
        hasProteinTarget: false,
        hasWaterTarget: false
    )

    static func from(
        calorieSummary: CalorieSummary,
        macroSummary: MacroSummary,
        waterSummary: WaterSummary
    ) -> TodayHealthIntelligenceNutritionProgress {
        TodayHealthIntelligenceNutritionProgress(
            calorieRemaining: calorieSummary.target > 0 ? calorieSummary.remaining : nil,
            proteinRemainingGrams: macroSummary.protein.target > 0 ? macroSummary.protein.remaining : nil,
            waterRemainingMl: waterSummary.targetMl > 0 ? waterSummary.remainingMl : nil,
            hasCalorieTarget: calorieSummary.target > 0,
            hasProteinTarget: macroSummary.protein.target > 0,
            hasWaterTarget: waterSummary.targetMl > 0
        )
    }
}
