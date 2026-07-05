//
//  HealthIntelligenceSummaryModels.swift
//  Fitness Coach
//
//  Forma — Domain summaries produced by Health Intelligence engines.
//

import Foundation

struct RecoverySummary: Equatable, Sendable, Codable {
    var score: Int?
    var status: RecoveryStatus
    var title: String
    var explanation: String
    var recommendedTraining: String
    var recommendedNutrition: String
    var confidence: RecoveryConfidence
    var contributingFactors: [RecoveryContributingFactor]
    var missingSignals: Set<RecoveryMissingSignal>

    static let unknown = RecoverySummary(
        score: nil,
        status: .unknown,
        title: "Recovery unclear",
        explanation: "Not enough recovery signals are available yet.",
        recommendedTraining: "Use how you feel before adding intensity today.",
        recommendedNutrition: "Stay on your usual plan until more data arrives.",
        confidence: .unknown,
        contributingFactors: [],
        missingSignals: [.sleep, .restingHeartRate, .hrv, .activity, .workouts, .trainingLoad]
    )

    static let placeholder = unknown
}

enum RecoveryStatus: String, Equatable, Sendable, Codable {
    case ready
    case moderate
    case low
    case unknown
}

enum RecoveryConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum RecoveryMissingSignal: String, Equatable, Sendable, Hashable, Codable {
    case sleep
    case restingHeartRate
    case hrv
    case activity
    case workouts
    case trainingLoad
}

enum RecoverySignalKind: String, Equatable, Sendable, Codable {
    case sleep
    case restingHeartRate
    case hrv
    case trainingLoad
    case consecutiveWorkouts
    case yesterdayActivity
    case limitedActivity
}

enum RecoveryFactorImpact: String, Equatable, Sendable, Codable {
    case positive
    case negative
    case neutral
    case limited
}

struct RecoveryContributingFactor: Equatable, Sendable, Codable {
    var signal: RecoverySignalKind
    var impact: RecoveryFactorImpact
    var detail: String
}

struct WorkoutSummary: Equatable, Sendable, Codable {
    var hasWorkout: Bool
    var primaryWorkoutType: FormaWorkoutCategory?
    var title: String
    var workoutCount: Int
    var totalDurationMinutes: Int
    var totalActiveCalories: Int?
    var intensity: WorkoutSummaryIntensity
    var demand: WorkoutDemand
    var latestWorkoutStart: Date?
    var latestWorkoutEnd: Date?
    var nutritionAdvice: String
    var hydrationAdviceMl: Int
    var explanation: String
    var confidence: WorkoutSummaryConfidence
    var sourceSummary: String

    static let noWorkout = WorkoutSummary(
        hasWorkout: false,
        primaryWorkoutType: nil,
        title: "Rest day so far",
        workoutCount: 0,
        totalDurationMinutes: 0,
        totalActiveCalories: nil,
        intensity: .unknown,
        demand: .low,
        latestWorkoutStart: nil,
        latestWorkoutEnd: nil,
        nutritionAdvice: "Stay on your usual plan today.",
        hydrationAdviceMl: 0,
        explanation: "No workouts are logged for today yet.",
        confidence: .low,
        sourceSummary: ""
    )
}

enum WorkoutSummaryIntensity: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum WorkoutDemand: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum WorkoutSummaryConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
}

struct ActivitySummary: Equatable, Sendable, Codable {
    var steps: Int?
    var activeEnergyKcal: Int?
    var exerciseMinutes: Int?

    static let empty = ActivitySummary(
        steps: nil,
        activeEnergyKcal: nil,
        exerciseMinutes: nil
    )
}

struct AdaptiveNutritionSummary: Equatable, Sendable, Codable {
    var proteinRecommendationGrams: Int?
    var suggestedProteinRemaining: Int?
    var waterIncreaseMl: Int
    var suggestedWaterRemainingMl: Int?
    var calorieAdvice: String
    var shouldChangeTarget: Bool
    var suggestedCalorieAdjustment: Int
    var adjustmentReason: String
    var priority: Int
    var confidence: AdaptiveNutritionConfidence
    var missingSignals: Set<AdaptiveNutritionMissingSignal>

    static let none = AdaptiveNutritionSummary(
        proteinRecommendationGrams: nil,
        suggestedProteinRemaining: nil,
        waterIncreaseMl: 0,
        suggestedWaterRemainingMl: nil,
        calorieAdvice: "",
        shouldChangeTarget: false,
        suggestedCalorieAdjustment: 0,
        adjustmentReason: "",
        priority: 0,
        confidence: .low,
        missingSignals: [.nutritionProgress, .userPlan, .workout]
    )
}

enum AdaptiveNutritionConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
}

enum AdaptiveNutritionMissingSignal: String, Equatable, Sendable, Hashable, Codable {
    case nutritionProgress
    case userPlan
    case workout
    case workoutCalories
    case recovery
    case trainingLoad
}

struct WeeklyStats: Equatable, Sendable, Codable {
    var totalWorkouts: Int
    var totalWorkoutMinutes: Int
    var totalActiveCalories: Int?
    var averageSteps: Int?
    var totalSteps: Int?
    var proteinHitDays: Int
    var calorieTargetHitDays: Int
    var waterHitDays: Int
    var averageRecoveryScore: Double?
    var lowRecoveryDays: Int
    var weightChangeKg: Double?
    var loggingConsistencyDays: Int

    static let empty = WeeklyStats(
        totalWorkouts: 0,
        totalWorkoutMinutes: 0,
        totalActiveCalories: nil,
        averageSteps: nil,
        totalSteps: nil,
        proteinHitDays: 0,
        calorieTargetHitDays: 0,
        waterHitDays: 0,
        averageRecoveryScore: nil,
        lowRecoveryDays: 0,
        weightChangeKg: nil,
        loggingConsistencyDays: 0
    )
}

enum WeeklyReviewConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
}

enum WeeklyReviewMissingSignal: String, Equatable, Sendable, Hashable, Codable {
    case sleep
    case hrv
    case weight
    case nutrition
    case workouts
    case activity
    case recovery
}

struct WeeklyHealthReview: Equatable, Sendable, Codable {
    var weekStartDate: Date
    var weekEndDate: Date
    var title: String
    var summary: String
    var stats: WeeklyStats
    var wins: [String]
    var risks: [String]
    var nextWeekFocus: [String]
    var confidence: WeeklyReviewConfidence
    var missingSignals: Set<WeeklyReviewMissingSignal>
    var generatedAt: Date

    static let empty = WeeklyHealthReview(
        weekStartDate: .distantPast,
        weekEndDate: .distantPast,
        title: "",
        summary: "",
        stats: .empty,
        wins: [],
        risks: [],
        nextWeekFocus: [],
        confidence: .low,
        missingSignals: [.activity, .nutrition, .weight, .recovery],
        generatedAt: .distantPast
    )
}

struct PlanHealthConfidence: Equatable, Sendable, Codable {
    var score: Double
    var label: String

    static let unknown = PlanHealthConfidence(
        score: 0,
        label: "Unknown"
    )
}

/// Health Intelligence recommendation — distinct from Today `NextBestActionState`.
typealias NextBestAction = HealthIntelligenceNextBestAction

enum NextBestActionDestination: String, Equatable, Sendable, Codable {
    case logMeal
    case addWater
    case askCoach
    case viewRecovery
    case logWeight
    case none
}

enum HealthNextBestActionReason: String, Equatable, Sendable, Codable {
    case postWorkoutRecovery
    case hydration
    case lowRecovery
    case noMealLogged
    case stepEncouragement
    case missingWeight
    case stayOnPlan
    case connectHealth
    case waitingForData
    case healthDataLimited
}

struct HealthIntelligenceNextBestAction: Equatable, Sendable, Codable {
    var id: String
    var title: String
    var message: String
    var ctaTitle: String
    var destination: NextBestActionDestination
    var priority: Int
    var reason: HealthNextBestActionReason
    var createdAt: Date
    var expiresAt: Date?

    static let none = HealthIntelligenceNextBestAction(
        id: "",
        title: "",
        message: "",
        ctaTitle: "",
        destination: .none,
        priority: 0,
        reason: .stayOnPlan,
        createdAt: .distantPast,
        expiresAt: nil
    )
}
