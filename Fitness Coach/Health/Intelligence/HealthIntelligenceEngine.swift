//
//  HealthIntelligenceEngine.swift
//  Fitness Coach
//
//  Forma — Orchestrates Health Intelligence sub-engines into a daily snapshot.
//

import Foundation

protocol HealthIntelligenceEngineing: Sendable {
    func generateSnapshot(
        for date: Date,
        calendar: Calendar
    ) async throws -> HealthIntelligenceSnapshot
}

struct HealthIntelligenceEngine: HealthIntelligenceEngineing {

    private let repository: any HealthDataRepositorying
    private let recoveryEngine: any RecoveryEngineing
    private let workoutEngine: any WorkoutIntelligenceEngineing
    private let trainingLoadEngine: any TrainingLoadEngineing
    private let adaptiveNutritionEngine: any AdaptiveNutritionEngineing
    private let weeklyReviewEngine: any WeeklyReviewEngineing
    private let planConfidenceEngine: any PlanConfidenceEngineing
    private let nextBestActionEngine: any HealthNextBestActionEngineing

    init(
        repository: any HealthDataRepositorying = HealthDataRepository(),
        recoveryEngine: any RecoveryEngineing = RecoveryEngine(),
        workoutEngine: any WorkoutIntelligenceEngineing = WorkoutIntelligenceEngine(),
        trainingLoadEngine: any TrainingLoadEngineing = TrainingLoadEngine(),
        adaptiveNutritionEngine: any AdaptiveNutritionEngineing = AdaptiveNutritionEngine(),
        weeklyReviewEngine: any WeeklyReviewEngineing = WeeklyReviewEngine(),
        planConfidenceEngine: any PlanConfidenceEngineing = PlanConfidenceEngine(),
        nextBestActionEngine: any HealthNextBestActionEngineing = HealthNextBestActionEngine()
    ) {
        self.repository = repository
        self.recoveryEngine = recoveryEngine
        self.workoutEngine = workoutEngine
        self.trainingLoadEngine = trainingLoadEngine
        self.adaptiveNutritionEngine = adaptiveNutritionEngine
        self.weeklyReviewEngine = weeklyReviewEngine
        self.planConfidenceEngine = planConfidenceEngine
        self.nextBestActionEngine = nextBestActionEngine
    }

    func generateSnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> HealthIntelligenceSnapshot {
        let samples = try await repository.normalizedSamples(for: date, calendar: calendar)

        let recovery = await recoveryEngine.recoverySummary(for: date, samples: samples)
        let workout = await workoutEngine.workoutSummary(for: date, samples: samples, calendar: calendar)
        let activity = Self.activitySummary(from: samples)
        let trainingLoad = await trainingLoadEngine.trainingLoad(for: date, samples: samples, calendar: calendar)
        let nutritionAdjustment = await adaptiveNutritionEngine.nutritionAdjustment(
            for: date,
            activity: activity,
            workout: workout,
            trainingLoad: trainingLoad
        )
        let weeklyReview = await weeklyReviewEngine.weeklyReview(
            endingOn: date,
            samples: samples,
            calendar: calendar
        )
        let planConfidence = await planConfidenceEngine.planConfidence(
            for: date,
            recovery: recovery,
            activity: activity,
            trainingLoad: trainingLoad
        )

        let provisionalSnapshot = HealthIntelligenceSnapshot(
            date: calendar.startOfDay(for: date),
            recovery: recovery,
            workout: workout,
            activity: activity,
            nutritionAdjustment: nutritionAdjustment,
            weeklyReview: weeklyReview,
            planConfidence: planConfidence,
            nextBestAction: .none
        )

        let action = await nextBestActionEngine.nextBestAction(for: date, snapshot: provisionalSnapshot)

        return HealthIntelligenceSnapshot(
            date: provisionalSnapshot.date,
            recovery: provisionalSnapshot.recovery,
            workout: provisionalSnapshot.workout,
            activity: provisionalSnapshot.activity,
            nutritionAdjustment: provisionalSnapshot.nutritionAdjustment,
            weeklyReview: provisionalSnapshot.weeklyReview,
            planConfidence: provisionalSnapshot.planConfidence,
            nextBestAction: action
        )
    }

    // MARK: - Private

    private static func activitySummary(from samples: [HealthNormalizedSample]) -> ActivitySummary {
        // TODO: Aggregate steps, active energy, and exercise minutes from normalized samples.
        let steps = samples
            .filter { $0.kind == .stepCount }
            .map(\.value)
            .max()
            .map { Int($0.rounded()) }

        let energy = samples
            .filter { $0.kind == .activeEnergy }
            .map(\.value)
            .reduce(0, +)

        let exerciseMinutes = samples
            .filter { $0.kind == .exerciseTime }
            .map(\.value)
            .reduce(0, +)

        return ActivitySummary(
            steps: steps,
            activeEnergyKcal: energy > 0 ? Int(energy.rounded()) : nil,
            exerciseMinutes: exerciseMinutes > 0 ? Int(exerciseMinutes.rounded()) : nil
        )
    }
}
