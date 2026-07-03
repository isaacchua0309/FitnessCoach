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

struct HealthIntelligenceEngineEvaluators: Sendable {
    var trainingLoad: @Sendable (TrainingLoadEngineInput) throws -> TrainingLoadSummary
    var workout: @Sendable (WorkoutIntelligenceInput) throws -> WorkoutSummary
    var recovery: @Sendable (RecoveryEngineInput) throws -> RecoverySummary
    var adaptiveNutrition: @Sendable (AdaptiveNutritionEngineInput) throws -> AdaptiveNutritionSummary
    var nextBestAction: @Sendable (NextBestActionEngineInput) throws -> NextBestAction
    var weeklyReview: @Sendable (WeeklyReviewEngineInput) throws -> WeeklyHealthReview?

    static func production(
        trainingLoadEngine: any TrainingLoadEngineing = TrainingLoadEngine(),
        workoutEngine: any WorkoutIntelligenceEngineing = WorkoutIntelligenceEngine(),
        recoveryEngine: any RecoveryEngineing = RecoveryEngine(),
        adaptiveNutritionEngine: any AdaptiveNutritionEngineing = AdaptiveNutritionEngine(),
        nextBestActionEngine: any HealthNextBestActionEngineing = HealthNextBestActionEngine(),
        weeklyReviewEngine: any WeeklyReviewEngineing = WeeklyReviewEngine()
    ) -> HealthIntelligenceEngineEvaluators {
        HealthIntelligenceEngineEvaluators(
            trainingLoad: { try $0.evaluate(trainingLoadEngine) },
            workout: { try $0.evaluate(workoutEngine) },
            recovery: { try $0.evaluate(recoveryEngine) },
            adaptiveNutrition: { try $0.evaluate(adaptiveNutritionEngine) },
            nextBestAction: { try $0.evaluate(nextBestActionEngine) },
            weeklyReview: { input in
                try weeklyReviewEngine.evaluate(input)
            }
        )
    }
}

private extension TrainingLoadEngineInput {
    func evaluate(_ engine: any TrainingLoadEngineing) throws -> TrainingLoadSummary {
        engine.evaluate(self)
    }
}

private extension WorkoutIntelligenceInput {
    func evaluate(_ engine: any WorkoutIntelligenceEngineing) throws -> WorkoutSummary {
        engine.evaluate(self)
    }
}

private extension RecoveryEngineInput {
    func evaluate(_ engine: any RecoveryEngineing) throws -> RecoverySummary {
        engine.evaluate(self)
    }
}

private extension AdaptiveNutritionEngineInput {
    func evaluate(_ engine: any AdaptiveNutritionEngineing) throws -> AdaptiveNutritionSummary {
        engine.evaluate(self)
    }
}

private extension NextBestActionEngineInput {
    func evaluate(_ engine: any HealthNextBestActionEngineing) throws -> NextBestAction {
        engine.evaluate(self)
    }
}

struct HealthIntelligenceEngine: HealthIntelligenceEngineing {

    private let contextBuilder: any HealthIntelligenceContextBuilding
    private let evaluators: HealthIntelligenceEngineEvaluators
    private let recoveryEngine: any RecoveryEngineing
    private let trainingLoadEngine: any TrainingLoadEngineing

    init(
        repository: any HealthDataRepositorying = HealthDataRepository(),
        contextBuilder: (any HealthIntelligenceContextBuilding)? = nil,
        evaluators: HealthIntelligenceEngineEvaluators? = nil,
        recoveryEngine: any RecoveryEngineing = RecoveryEngine(),
        trainingLoadEngine: any TrainingLoadEngineing = TrainingLoadEngine()
    ) {
        self.contextBuilder = contextBuilder ?? HealthIntelligenceContextBuilder(repository: repository)
        self.evaluators = evaluators ?? .production(
            recoveryEngine: recoveryEngine,
            trainingLoadEngine: trainingLoadEngine
        )
        self.recoveryEngine = recoveryEngine
        self.trainingLoadEngine = trainingLoadEngine
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
            work: { try evaluators.trainingLoad(context.trainingLoadInput) }
        )

        let workoutSummary = runSection(
            .workout,
            fallback: .noWorkout,
            work: { try evaluators.workout(context.workoutInput(trainingLoad: trainingLoad)) }
        )
        let workout = workoutSummary.hasWorkout ? workoutSummary : nil

        let recovery = runSection(
            .recovery,
            fallback: recoveryFallback(for: context),
            work: { try evaluators.recovery(context.recoveryInput(trainingLoad: trainingLoad)) }
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
                try evaluators.adaptiveNutrition(
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
                    try evaluators.nextBestAction(
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
            recoveryEngine: recoveryEngine,
            trainingLoadEngine: trainingLoadEngine,
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
            work: { try evaluators.weeklyReview(input) }
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
