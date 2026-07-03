//
//  HealthIntelligenceEngine.swift
//  Fitness Coach
//
//  Forma — Orchestrates Health Intelligence sub-engines into a daily snapshot.
//

import Foundation

protocol HealthIntelligenceEngineing: Sendable {
    func composeSnapshot(
        for date: Date,
        calendar: Calendar
    ) async -> HealthIntelligenceSnapshot

    func generateSnapshot(
        for date: Date,
        calendar: Calendar
    ) async throws -> HealthIntelligenceSnapshot
}

extension HealthIntelligenceEngineing {
    func composeSnapshot(for date: Date) async -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: .current)
    }

    func generateSnapshot(for date: Date) async throws -> HealthIntelligenceSnapshot {
        try await generateSnapshot(for: date, calendar: .current)
    }
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

    func composeSnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot {
        let day = calendar.startOfDay(for: date)
        let availability = await repository.getHealthDataAvailability()
        let dailyMetrics = await repository.getDailyMetrics(for: day, calendar: calendar)

        let weekWorkouts = await recentWeekWorkouts(endingOn: day, calendar: calendar)
        let weekMetrics = await recentWeekMetrics(endingOn: day, calendar: calendar)

        let activity = HealthIntelligenceBaseline.activitySummary(
            metrics: dailyMetrics,
            availability: availability
        )
        let workout = HealthIntelligenceBaseline.workoutSummary(
            workouts: weekWorkouts,
            on: day,
            calendar: calendar
        )
        let recovery = HealthIntelligenceBaseline.recoverySummary(availability: availability)
        let nutritionAdjustment = await adaptiveNutritionEngine.nutritionAdjustment(
            for: day,
            activity: activity,
            workout: workout,
            trainingLoad: .empty
        )
        let daysWithActivityData = weekMetrics.filter { HealthIntelligenceBaseline.dayHasActivity($0) }.count
        let weeklyReview = HealthIntelligenceBaseline.weeklyReview(
            metricsInWeek: weekMetrics,
            workoutDays: HealthIntelligenceBaseline.workoutDays(
                in: weekWorkouts,
                endingOn: day,
                calendar: calendar
            )
        )
        let planConfidence = HealthIntelligenceBaseline.planConfidence(
            availability: availability,
            daysWithActivityData: daysWithActivityData
        )
        let nextBestAction = HealthIntelligenceBaseline.nextBestAction(
            availability: availability,
            activity: activity,
            workout: workout
        )

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: recovery,
            workout: workout,
            activity: activity,
            nutritionAdjustment: nutritionAdjustment,
            weeklyReview: weeklyReview,
            planConfidence: planConfidence,
            nextBestAction: nextBestAction
        )
    }

    func generateSnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: calendar)
    }

    // MARK: - Private

    private func recentWeekWorkouts(
        endingOn day: Date,
        calendar: Calendar
    ) async -> [NormalizedWorkout] {
        await repository.getRecentWorkouts(
            days: HealthIntelligenceBaseline.minimumWeeklyReviewDays,
            calendar: calendar
        )
    }

    private func recentWeekMetrics(
        endingOn day: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        guard let range = HealthIntelligenceBaseline.metricsInWeek(endingOn: day, calendar: calendar) else {
            return []
        }
        return await repository.getDailyMetrics(
            from: range.start,
            to: range.end,
            calendar: calendar
        )
    }
}
