//
//  HealthNextBestActionEngine.swift
//  Fitness Coach
//
//  Forma — Health Intelligence next-best-action recommendations.
//
//  Note: Renamed from `NextBestActionEngine` to avoid conflict with
//  `Features/Today/Model/NextBestActionEngine` (Today Mission Control).
//
//  Pure deterministic engine: no HealthKit, no UI dependencies.
//

import Foundation

// MARK: - Input

struct NextBestActionEngineInput: Equatable, Sendable {
    let targetDate: Date
    let timeOfDay: Date
    let nutritionProgress: AdaptiveNutritionProgress
    let userPlan: AdaptiveNutritionUserPlan
    let recoverySummary: RecoverySummary
    let workoutSummary: WorkoutSummary
    let activitySummary: ActivitySummary
    let adaptiveNutritionSummary: AdaptiveNutritionSummary
    let trainingLoadSummary: TrainingLoadSummary
    let hasLoggedWeightRecently: Bool
    let calendar: Calendar
}

// MARK: - Policy

enum NextBestActionPolicy {
    static let meaningfulProteinRemainingGrams = 15.0
    static let proteinHitProgress = 0.95
    static let waterBehindRemainingMl = 750
    static let waterBehindProgress = 0.55
    static let lateMorningHour = 11
    static let afternoonHour = 15
    static let lateDayHour = 15
    static let lowStepsThreshold = 4_500
    static let postWorkoutExpiryHours = 3
}

// MARK: - Engine

struct HealthNextBestActionEngine: NextBestActionProviding {

    func evaluate(_ input: NextBestActionEngineInput) throws -> NextBestAction {
        let createdAt = input.timeOfDay

        if let action = postWorkoutRecoveryAction(input: input, createdAt: createdAt) {
            return action
        }
        if let action = hydrationAction(input: input, createdAt: createdAt) {
            return action
        }
        if let action = lowRecoveryAction(input: input, createdAt: createdAt) {
            return action
        }
        if let action = noMealLoggedAction(input: input, createdAt: createdAt) {
            return action
        }
        if let action = stepEncouragementAction(input: input, createdAt: createdAt) {
            return action
        }
        if let action = missingWeightAction(input: input, createdAt: createdAt) {
            return action
        }
        return defaultAction(input: input, createdAt: createdAt)
    }

    // MARK: - Rules

    private func postWorkoutRecoveryAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        let workout = input.workoutSummary
        let progress = input.nutritionProgress

        guard workout.hasWorkout else { return nil }
        guard workout.demand == .high || workout.demand == .moderate else { return nil }
        guard progress.hasProteinTarget else { return nil }
        guard !isProteinTargetHit(progress) else { return nil }
        guard progress.proteinRemainingGrams >= NextBestActionPolicy.meaningfulProteinRemainingGrams else {
            return nil
        }

        return NextBestAction(
            id: "post-workout-recovery",
            title: "Refuel after training",
            message: "Log a protein-forward meal to support recovery.",
            ctaTitle: "Log meal",
            destination: .logMeal,
            priority: 1,
            reason: .postWorkoutRecovery,
            createdAt: createdAt,
            expiresAt: input.calendar.date(
                byAdding: .hour,
                value: NextBestActionPolicy.postWorkoutExpiryHours,
                to: createdAt
            )
        )
    }

    private func hydrationAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        let progress = input.nutritionProgress
        let adaptive = input.adaptiveNutritionSummary

        let waterBehind = isWaterBehind(progress)
        let needsWorkoutHydration = adaptive.waterIncreaseMl > 0
            || input.workoutSummary.hydrationAdviceMl > 0

        guard waterBehind || needsWorkoutHydration else { return nil }

        return NextBestAction(
            id: "hydration",
            title: "Drink more water",
            message: "Hydration will help you feel better through the rest of today.",
            ctaTitle: "Add water",
            destination: .addWater,
            priority: 2,
            reason: .hydration,
            createdAt: createdAt,
            expiresAt: endOfDay(for: input.targetDate, calendar: input.calendar)
        )
    }

    private func lowRecoveryAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        guard input.recoverySummary.status == .low else { return nil }

        return NextBestAction(
            id: "low-recovery",
            title: "Take recovery seriously",
            message: "A lighter day with steady fuel may feel better right now.",
            ctaTitle: "Ask Coach",
            destination: .askCoach,
            priority: 3,
            reason: .lowRecovery,
            createdAt: createdAt,
            expiresAt: endOfDay(for: input.targetDate, calendar: input.calendar)
        )
    }

    private func noMealLoggedAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        let hour = input.calendar.component(.hour, from: input.timeOfDay)
        guard hour >= NextBestActionPolicy.lateMorningHour else { return nil }
        guard input.nutritionProgress.caloriesConsumed == 0 else { return nil }

        return NextBestAction(
            id: "log-first-meal",
            title: "Log your first meal",
            message: "A quick meal log keeps today on track.",
            ctaTitle: "Log meal",
            destination: .logMeal,
            priority: 4,
            reason: .noMealLogged,
            createdAt: createdAt,
            expiresAt: afternoonExpiry(for: input.targetDate, calendar: input.calendar)
        )
    }

    private func stepEncouragementAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        let hour = input.calendar.component(.hour, from: input.timeOfDay)
        guard hour >= NextBestActionPolicy.lateDayHour else { return nil }
        guard !input.workoutSummary.hasWorkout else { return nil }

        let steps = input.activitySummary.steps ?? 0
        guard steps < NextBestActionPolicy.lowStepsThreshold else { return nil }

        return NextBestAction(
            id: "step-encouragement",
            title: "Move a little more",
            message: "A short walk can help you close the day positively.",
            ctaTitle: "Ask Coach",
            destination: .askCoach,
            priority: 5,
            reason: .stepEncouragement,
            createdAt: createdAt,
            expiresAt: endOfDay(for: input.targetDate, calendar: input.calendar)
        )
    }

    private func missingWeightAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction? {
        guard !input.hasLoggedWeightRecently else { return nil }

        return NextBestAction(
            id: "log-weight",
            title: "Log your weight",
            message: "A recent weigh-in helps keep your plan confidence up to date.",
            ctaTitle: "Log weight",
            destination: .logWeight,
            priority: 6,
            reason: .missingWeight,
            createdAt: createdAt,
            expiresAt: endOfDay(for: input.targetDate, calendar: input.calendar)
        )
    }

    private func defaultAction(
        input: NextBestActionEngineInput,
        createdAt: Date
    ) -> NextBestAction {
        NextBestAction(
            id: "stay-on-plan",
            title: "Stay on plan",
            message: "You are in a steady spot. Keep following your usual plan today.",
            ctaTitle: "",
            destination: .none,
            priority: 7,
            reason: .stayOnPlan,
            createdAt: createdAt,
            expiresAt: nil
        )
    }

    // MARK: - Helpers

    private func isProteinTargetHit(_ progress: AdaptiveNutritionProgress) -> Bool {
        guard progress.hasProteinTarget else { return false }
        return progress.proteinConsumedGrams / progress.proteinTargetGrams
            >= NextBestActionPolicy.proteinHitProgress
    }

    private func isWaterBehind(_ progress: AdaptiveNutritionProgress) -> Bool {
        guard progress.hasWaterTarget else { return false }
        if progress.waterRemainingMl >= NextBestActionPolicy.waterBehindRemainingMl {
            return true
        }
        let ratio = Double(progress.waterConsumedMl) / Double(progress.waterTargetMl)
        return ratio < NextBestActionPolicy.waterBehindProgress
    }

    private func endOfDay(for date: Date, calendar: Calendar) -> Date? {
        let day = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)
    }

    private func afternoonExpiry(for date: Date, calendar: Calendar) -> Date? {
        let day = calendar.startOfDay(for: date)
        return calendar.date(
            bySettingHour: NextBestActionPolicy.afternoonHour,
            minute: 0,
            second: 0,
            of: day
        )
    }
}
