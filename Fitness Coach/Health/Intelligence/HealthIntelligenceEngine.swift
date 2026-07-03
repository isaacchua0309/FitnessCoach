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

    private let contextBuilder: any HealthIntelligenceContextBuilding
    private let weeklyReviewEngine: any WeeklyReviewEngineing
    private let planConfidenceEngine: any PlanConfidenceEngineing
    private let nextBestActionEngine: any HealthNextBestActionEngineing

    init(
        repository: any HealthDataRepositorying = HealthDataRepository(),
        contextBuilder: (any HealthIntelligenceContextBuilding)? = nil,
        weeklyReviewEngine: any WeeklyReviewEngineing = WeeklyReviewEngine(),
        planConfidenceEngine: any PlanConfidenceEngineing = PlanConfidenceEngine(),
        nextBestActionEngine: any HealthNextBestActionEngineing = HealthNextBestActionEngine()
    ) {
        self.contextBuilder = contextBuilder ?? HealthIntelligenceContextBuilder(repository: repository)
        self.weeklyReviewEngine = weeklyReviewEngine
        self.planConfidenceEngine = planConfidenceEngine
        self.nextBestActionEngine = nextBestActionEngine
    }

    func composeSnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot {
        let context = await contextBuilder.buildContext(for: date, calendar: calendar)
        let day = context.targetDate
        let summaries = context.summaries

        let workout = summaries.workout.hasWorkout ? summaries.workout : nil
        let daysWithActivityData = context.metricsLast7Days.filter {
            HealthIntelligenceBaseline.dayHasActivity($0)
        }.count

        let weeklyReview = context.weeklyReviewInput.flatMap { weeklyReviewEngine.evaluate($0) }
            ?? HealthIntelligenceBaseline.weeklyReview(
                metricsInWeek: context.metricsLast7Days,
                workoutDays: HealthIntelligenceBaseline.workoutDays(
                    in: workoutsInWeek(from: context),
                    endingOn: day,
                    calendar: calendar
                ),
                weekEndDate: day,
                calendar: calendar
            )

        let planConfidence = await planConfidenceEngine.planConfidence(
            for: day,
            recovery: summaries.recovery,
            activity: summaries.activity,
            trainingLoad: summaries.trainingLoad
        )

        let availabilityAction = HealthIntelligenceBaseline.nextBestAction(
            availability: context.availability,
            activity: summaries.activity,
            workout: workout
        )
        let nextBestAction = availabilityAction == .none
            ? nextBestActionEngine.evaluate(context.nextBestActionInput)
            : availabilityAction

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: summaries.recovery,
            workout: workout,
            activity: summaries.activity,
            nutritionAdjustment: summaries.adaptiveNutrition,
            weeklyReview: weeklyReview,
            planConfidence: degradedPlanConfidence(
                engineConfidence: planConfidence,
                availability: context.availability,
                daysWithActivityData: daysWithActivityData
            ),
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

    private func degradedPlanConfidence(
        engineConfidence: PlanHealthConfidence,
        availability: HealthDataAvailability,
        daysWithActivityData: Int
    ) -> PlanHealthConfidence {
        if engineConfidence != .unknown {
            return engineConfidence
        }
        return HealthIntelligenceBaseline.planConfidence(
            availability: availability,
            daysWithActivityData: daysWithActivityData
        )
    }

    private func workoutsInWeek(from context: HealthIntelligenceContext) -> [NormalizedWorkout] {
        let calendar = context.calendar
        let day = context.targetDate
        guard let range = HealthIntelligenceBaseline.metricsInWeek(endingOn: day, calendar: calendar) else {
            return []
        }
        return HealthIntelligenceContextBuilder.workouts(
            in: range,
            from: context.trainingLoadInput.workoutsLast28Days,
            calendar: calendar
        )
    }
}
