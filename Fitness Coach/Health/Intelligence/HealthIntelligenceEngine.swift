//
//  HealthIntelligenceEngine.swift
//  Fitness Coach
//
//  Forma — Orchestrates Health Intelligence sub-engines into a daily snapshot.
//

import Foundation

enum HealthIntelligenceEngineEvaluationError: Error, Equatable, Sendable {
    case simulatedFailure(HealthIntelligenceEngineSection)
}

protocol HealthIntelligenceEngineing: Sendable {
    func composeSnapshot(
        for date: Date,
        calendar: Calendar,
        mode: HealthIntelligenceComposeMode
    ) async -> HealthIntelligenceSnapshot

    func generateSnapshot(
        for date: Date,
        calendar: Calendar
    ) async throws -> HealthIntelligenceSnapshot
}

extension HealthIntelligenceEngineing {
    func composeSnapshot(for date: Date) async -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: .current, mode: .today)
    }

    func composeSnapshot(
        for date: Date,
        calendar: Calendar
    ) async -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: calendar, mode: .today)
    }

    func generateSnapshot(for date: Date) async throws -> HealthIntelligenceSnapshot {
        try await generateSnapshot(for: date, calendar: .current)
    }
}

struct HealthIntelligenceEngine: HealthIntelligenceEngineing {

    private let contextBuilder: any HealthIntelligenceContextBuilding
    private let dependencies: HealthIntelligenceEngineDependencies

    init(
        contextBuilder: any HealthIntelligenceContextBuilding,
        dependencies: HealthIntelligenceEngineDependencies
    ) {
        self.contextBuilder = contextBuilder
        self.dependencies = dependencies
    }

    func composeSnapshot(
        for date: Date,
        calendar: Calendar = .current,
        mode: HealthIntelligenceComposeMode = .today
    ) async -> HealthIntelligenceSnapshot {
        let context = await contextBuilder.buildContext(for: date, calendar: calendar)

        return composeSnapshot(from: context, mode: mode)
    }

    func generateSnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: calendar, mode: .today)
    }

    // MARK: - Composition

    private func composeSnapshot(
        from context: HealthIntelligenceContext,
        mode: HealthIntelligenceComposeMode
    ) -> HealthIntelligenceSnapshot {
        let day = context.targetDate

        let trainingLoad = runSection(
            .trainingLoad,
            fallback: .unknown,
            work: { try dependencies.trainingLoad.evaluate(context.trainingLoadInput) }
        )

        let workoutSummary = runSection(
            .workout,
            fallback: .noWorkout,
            work: { try dependencies.workout.evaluate(context.workoutInput(trainingLoad: trainingLoad)) }
        )
        let workout = workoutSummary.hasWorkout ? workoutSummary : nil

        let recovery = runSection(
            .recovery,
            fallback: recoveryFallback(for: context),
            work: { try dependencies.recovery.evaluate(context.recoveryInput(trainingLoad: trainingLoad)) }
        )

        let activity = runSection(
            .activity,
            fallback: activityFallback(for: context),
            work: { context.activitySummary() }
        )

        let adaptiveNutrition = runSection(
            .adaptiveNutrition,
            fallback: .none,
            work: {
                try dependencies.adaptiveNutrition.evaluate(
                    context.adaptiveNutritionInput(
                        workout: workoutSummary,
                        recovery: recovery,
                        activity: activity,
                        trainingLoad: trainingLoad
                    )
                )
            }
        )

        let availabilityAction = HealthIntelligenceBaseline.nextBestAction(
            availability: context.availability,
            activity: activity,
            workout: workout
        )
        let nextBestAction: NextBestAction
        if availabilityAction == .none {
            nextBestAction = runSection(
                .nextBestAction,
                fallback: stayOnPlanAction(for: context),
                work: {
                    try dependencies.nextBestAction.evaluate(
                        context.nextBestActionInput(
                            workout: workoutSummary,
                            recovery: recovery,
                            activity: activity,
                            adaptiveNutrition: adaptiveNutrition,
                            trainingLoad: trainingLoad
                        )
                    )
                }
            )
        } else {
            nextBestAction = availabilityAction
        }

        let weeklyReview = composeWeeklyReview(from: context, mode: mode)

        let daysWithActivityData = context.metricsLast7Days.filter {
            HealthIntelligenceBaseline.dayHasActivity($0)
        }.count
        let planConfidence = runSection(
            .planConfidence,
            fallback: HealthIntelligenceBaseline.planConfidence(
                availability: context.availability,
                daysWithActivityData: daysWithActivityData
            ),
            work: {
                HealthIntelligenceBaseline.planConfidence(
                    availability: context.availability,
                    daysWithActivityData: daysWithActivityData
                )
            }
        )

        return HealthIntelligenceSnapshot(
            date: day,
            recovery: recovery,
            workout: workout,
            activity: activity,
            nutritionAdjustment: adaptiveNutrition,
            weeklyReview: weeklyReview,
            planConfidence: planConfidence,
            nextBestAction: nextBestAction
        )
    }

    private func composeWeeklyReview(
        from context: HealthIntelligenceContext,
        mode: HealthIntelligenceComposeMode
    ) -> WeeklyHealthReview? {
        guard let weeklyContext = context.weeklyReviewContext else { return nil }
        guard HealthIntelligenceComposeModePolicy.shouldIncludeWeeklyReview(
            mode: mode,
            targetDate: context.targetDate,
            hasEnoughWeeklyActivity: weeklyContext.hasEnoughActivity,
            calendar: context.calendar
        ) else {
            return nil
        }

        if mode == .preview {
            return nil
        }

        let recoverySummaries = HealthIntelligenceWeeklyReviewSupport.recoverySummariesForWeek(
            weekContext: weeklyContext,
            metrics: context.metricsLast28Days,
            workouts: context.workoutsLast28Days,
            sleepRecords: context.sleepRecords,
            heartMetrics: context.heartMetrics,
            baselineContext: context.baselineContext,
            trainingLoadProvider: dependencies.trainingLoad,
            recoveryProvider: dependencies.recovery,
            calendar: context.calendar
        )

        guard let input = context.weeklyReviewInput(
            recoverySummaries: recoverySummaries,
            generatedAt: context.generatedAt
        ) else {
            return baselineWeeklyReview(from: context)
        }

        if let review = runOptionalSection(
            .weeklyReview,
            work: { try dependencies.weeklyReview.evaluate(input) }
        ) {
            return review
        }

        return baselineWeeklyReview(from: context)
    }

    // MARK: - Safe evaluation

    private func runSection<T>(
        _ section: HealthIntelligenceEngineSection,
        fallback: T,
        work: () throws -> T
    ) -> T {
        do {
            return try work()
        } catch {
            HealthIntelligenceEngineLogger.sectionFailure(section, error: error)
            return fallback
        }
    }

    private func runOptionalSection<T>(
        _ section: HealthIntelligenceEngineSection,
        work: () throws -> T?
    ) -> T? {
        do {
            return try work()
        } catch {
            HealthIntelligenceEngineLogger.sectionFailure(section, error: error)
            return nil
        }
    }

    // MARK: - Fallbacks

    private func recoveryFallback(for context: HealthIntelligenceContext) -> RecoverySummary {
        guard context.availability.isHealthDataAvailable else {
            return .unknown
        }
        return HealthIntelligenceBaseline.recoverySummary(availability: context.availability)
    }

    private func activityFallback(for context: HealthIntelligenceContext) -> ActivitySummary {
        HealthIntelligenceBaseline.activitySummary(
            metrics: context.todayMetrics,
            availability: context.availability
        )
    }

    private func stayOnPlanAction(for context: HealthIntelligenceContext) -> NextBestAction {
        NextBestAction(
            id: "stay-on-plan",
            title: "Stay on plan",
            message: "You are in a steady spot. Keep following your usual plan today.",
            ctaTitle: "",
            destination: .none,
            priority: 7,
            reason: .stayOnPlan,
            createdAt: context.generatedAt,
            expiresAt: nil
        )
    }

    private func baselineWeeklyReview(from context: HealthIntelligenceContext) -> WeeklyHealthReview? {
        guard let weeklyContext = context.weeklyReviewContext, weeklyContext.hasEnoughActivity else {
            return nil
        }
        return HealthIntelligenceBaseline.weeklyReview(
            metricsInWeek: weeklyContext.weekMetrics,
            workoutDays: HealthIntelligenceBaseline.workoutDays(
                in: weeklyContext.weekWorkouts,
                endingOn: context.targetDate,
                calendar: context.calendar
            ),
            weekEndDate: context.targetDate,
            calendar: context.calendar
        )
    }
}
