//
//  AdaptiveNutritionEngine.swift
//  Fitness Coach
//
//  Forma — Training-aware nutrition guidance without automatic target changes.
//
//  Pure deterministic engine: no repository, no HealthKit, no medical claims.
//

import Foundation

// MARK: - Input models

struct AdaptiveNutritionProgress: Equatable, Sendable {
    var proteinConsumedGrams: Double
    var proteinTargetGrams: Double
    var proteinRemainingGrams: Double
    var caloriesConsumed: Int
    var calorieTarget: Int
    var calorieRemaining: Int
    var waterConsumedMl: Int
    var waterTargetMl: Int
    var waterRemainingMl: Int

    var hasProteinTarget: Bool { proteinTargetGrams > 0 }
    var hasCalorieTarget: Bool { calorieTarget > 0 }
    var hasWaterTarget: Bool { waterTargetMl > 0 }
    var isAvailable: Bool { hasProteinTarget || hasCalorieTarget || hasWaterTarget }

    static let unavailable = AdaptiveNutritionProgress(
        proteinConsumedGrams: 0,
        proteinTargetGrams: 0,
        proteinRemainingGrams: 0,
        caloriesConsumed: 0,
        calorieTarget: 0,
        calorieRemaining: 0,
        waterConsumedMl: 0,
        waterTargetMl: 0,
        waterRemainingMl: 0
    )
}

struct AdaptiveNutritionUserPlan: Equatable, Sendable {
    var calorieTarget: Int
    var proteinTargetGrams: Double
    var waterTargetMl: Int

    var isAvailable: Bool { calorieTarget > 0 && proteinTargetGrams > 0 }

    static let unavailable = AdaptiveNutritionUserPlan(
        calorieTarget: 0,
        proteinTargetGrams: 0,
        waterTargetMl: 0
    )
}

struct AdaptiveNutritionEngineInput: Equatable, Sendable {
    let targetDate: Date
    let nutritionProgress: AdaptiveNutritionProgress
    let userPlan: AdaptiveNutritionUserPlan
    let workoutSummary: WorkoutSummary
    let recoverySummary: RecoverySummary
    let activitySummary: ActivitySummary
    let trainingLoadSummary: TrainingLoadSummary
    let baselineContext: HealthBaselineContext
    let calendar: Calendar
}

// MARK: - Policy

enum AdaptiveNutritionPolicy {
    static let highDemandProteinLowerBound = 30
    static let highDemandProteinUpperBound = 45
    static let moderateDemandProteinLowerBound = 20
    static let moderateDemandProteinUpperBound = 35
    static let lowCalorieProgressAfterWorkout = 0.35
    static let proteinHitProgress = 0.95
}

// MARK: - Engine

protocol AdaptiveNutritionEngineing: Sendable {
    func evaluate(_ input: AdaptiveNutritionEngineInput) -> AdaptiveNutritionSummary
}

struct AdaptiveNutritionEngine: AdaptiveNutritionEngineing {

    func evaluate(_ input: AdaptiveNutritionEngineInput) -> AdaptiveNutritionSummary {
        var missingSignals = Set<AdaptiveNutritionMissingSignal>()
        let progress = input.nutritionProgress
        let plan = input.userPlan
        let workout = input.workoutSummary
        let recovery = input.recoverySummary
        let trainingLoad = input.trainingLoadSummary

        if !progress.isAvailable {
            missingSignals.insert(.nutritionProgress)
        }
        if !plan.isAvailable {
            missingSignals.insert(.userPlan)
        }
        if !workout.hasWorkout {
            missingSignals.insert(.workout)
        }
        if workout.hasWorkout, workout.totalActiveCalories == nil {
            missingSignals.insert(.workoutCalories)
        }
        if recovery.status == .unknown {
            missingSignals.insert(.recovery)
        }
        if trainingLoad.status == .unknown {
            missingSignals.insert(.trainingLoad)
        }

        let proteinGuidance = proteinGuidanceGrams(
            workout: workout,
            recovery: recovery,
            trainingLoad: trainingLoad
        )
        let suggestedProteinRemaining = suggestedProteinRemaining(
            progress: progress,
            proteinGuidance: proteinGuidance
        )

        let waterIncreaseMl = waterIncrease(
            workout: workout,
            trainingLoad: trainingLoad
        )
        let suggestedWaterRemainingMl = suggestedWaterRemaining(
            progress: progress,
            waterIncreaseMl: waterIncreaseMl
        )

        let calorieAdvice = calorieAdvice(
            progress: progress,
            workout: workout,
            recovery: recovery,
            proteinGuidance: proteinGuidance
        )

        let priority = resolvePriority(
            workout: workout,
            recovery: recovery,
            trainingLoad: trainingLoad,
            progress: progress
        )

        let confidence = resolveConfidence(
            progress: progress,
            plan: plan,
            workout: workout
        )

        let adjustmentReason = adjustmentReason(
            workout: workout,
            recovery: recovery,
            trainingLoad: trainingLoad,
            proteinGuidance: proteinGuidance
        )

        return AdaptiveNutritionSummary(
            proteinRecommendationGrams: proteinGuidance,
            suggestedProteinRemaining: suggestedProteinRemaining,
            waterIncreaseMl: waterIncreaseMl,
            suggestedWaterRemainingMl: suggestedWaterRemainingMl,
            calorieAdvice: calorieAdvice,
            shouldChangeTarget: false,
            suggestedCalorieAdjustment: 0,
            adjustmentReason: adjustmentReason,
            priority: priority,
            confidence: confidence,
            missingSignals: missingSignals
        )
    }

    // MARK: - Protein

    private func proteinGuidanceGrams(
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        trainingLoad: TrainingLoadSummary
    ) -> Int? {
        guard workout.hasWorkout else { return nil }

        var lower = 0
        var upper = 0

        switch workout.demand {
        case .high:
            lower = AdaptiveNutritionPolicy.highDemandProteinLowerBound
            upper = AdaptiveNutritionPolicy.highDemandProteinUpperBound
        case .moderate:
            lower = AdaptiveNutritionPolicy.moderateDemandProteinLowerBound
            upper = AdaptiveNutritionPolicy.moderateDemandProteinUpperBound
        case .low, .unknown:
            return nil
        }

        if recovery.status == .low {
            lower = max(lower, AdaptiveNutritionPolicy.moderateDemandProteinLowerBound)
            upper = max(upper, AdaptiveNutritionPolicy.highDemandProteinLowerBound)
        }

        if trainingLoad.status == .high || trainingLoad.status == .overreaching {
            lower = max(lower, AdaptiveNutritionPolicy.moderateDemandProteinLowerBound)
            upper = max(upper, AdaptiveNutritionPolicy.highDemandProteinUpperBound)
        }

        return (lower + upper) / 2
    }

    private func suggestedProteinRemaining(
        progress: AdaptiveNutritionProgress,
        proteinGuidance: Int?
    ) -> Int? {
        guard progress.hasProteinTarget else { return nil }

        let remaining = Int(max(0, progress.proteinRemainingGrams.rounded()))
        guard let proteinGuidance else {
            return remaining
        }

        if progress.proteinTargetGrams > 0,
           progress.proteinConsumedGrams / progress.proteinTargetGrams >= AdaptiveNutritionPolicy.proteinHitProgress {
            return remaining
        }

        return max(remaining, proteinGuidance)
    }

    // MARK: - Water

    private func waterIncrease(
        workout: WorkoutSummary,
        trainingLoad: TrainingLoadSummary
    ) -> Int {
        var increase = workout.hasWorkout ? workout.hydrationAdviceMl : 0

        if trainingLoad.status == .high || trainingLoad.status == .overreaching {
            increase = max(increase, WorkoutIntelligencePolicy.hydrationModerateMl)
        }

        return increase
    }

    private func suggestedWaterRemaining(
        progress: AdaptiveNutritionProgress,
        waterIncreaseMl: Int
    ) -> Int? {
        guard progress.hasWaterTarget else { return nil }
        return max(0, progress.waterRemainingMl) + waterIncreaseMl
    }

    // MARK: - Calories

    private func calorieAdvice(
        progress: AdaptiveNutritionProgress,
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        proteinGuidance: Int?
    ) -> String {
        if recovery.status == .low {
            return "Keep meals steady today and prioritize protein and fluids over cutting harder."
        }

        guard workout.hasWorkout else {
            return "Stay on your usual plan today."
        }

        if let proteinGuidance,
           progress.hasProteinTarget,
           progress.proteinConsumedGrams / progress.proteinTargetGrams >= AdaptiveNutritionPolicy.proteinHitProgress {
            return "Protein is in a good place. Focus on balanced meals and hydration for the rest of the day."
        }

        if workout.demand == .high || workout.demand == .moderate,
           progress.hasCalorieTarget {
            let progressRatio = Double(progress.caloriesConsumed) / Double(progress.calorieTarget)
            if progressRatio < AdaptiveNutritionPolicy.lowCalorieProgressAfterWorkout {
                return "After today's session, aim for a solid meal so you are not under-fueling recovery."
            }
        }

        if let proteinGuidance {
            return "Support today's training with steady meals and enough protein across the rest of the day."
        }

        return "Stay on your usual plan today."
    }

    // MARK: - Priority & confidence

    private func resolvePriority(
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        trainingLoad: TrainingLoadSummary,
        progress: AdaptiveNutritionProgress
    ) -> Int {
        if recovery.status == .low { return 3 }
        if trainingLoad.status == .overreaching { return 3 }
        if workout.demand == .high { return 2 }
        if workout.hasWorkout,
           progress.hasCalorieTarget,
           Double(progress.caloriesConsumed) / Double(progress.calorieTarget)
               < AdaptiveNutritionPolicy.lowCalorieProgressAfterWorkout {
            return 2
        }
        if workout.demand == .moderate { return 1 }
        return 0
    }

    private func resolveConfidence(
        progress: AdaptiveNutritionProgress,
        plan: AdaptiveNutritionUserPlan,
        workout: WorkoutSummary
    ) -> AdaptiveNutritionConfidence {
        guard progress.isAvailable, plan.isAvailable else { return .low }

        if workout.hasWorkout {
            if workout.totalActiveCalories != nil, workout.confidence != .low {
                return .high
            }
            return .moderate
        }

        return progress.hasProteinTarget && progress.hasCalorieTarget ? .moderate : .low
    }

    private func adjustmentReason(
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        trainingLoad: TrainingLoadSummary,
        proteinGuidance: Int?
    ) -> String {
        if !workout.hasWorkout {
            return "No workout guidance needed today."
        }
        if recovery.status == .low {
            return "Recovery is low, so guidance favors consistency over restriction."
        }
        if trainingLoad.status == .overreaching {
            return "Recent training load is elevated, so protein and hydration take priority."
        }
        if let proteinGuidance {
            return "Today's session supports extra protein and hydration guidance."
        }
        return "Workout demand is light, so your current plan is enough."
    }
}
