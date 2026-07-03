//
//  WeeklyReviewService.swift
//  Fitness Coach
//
//  Forma — Deterministic weekly review generation with cache-first loading.
//

import Foundation

protocol WeeklyReviewServing: Sendable {
    func getLatestCompletedWeeklyReview(calendar: Calendar) async -> WeeklyHealthReview?
    func getWeeklyReview(for weekStartDate: Date, calendar: Calendar) async -> WeeklyHealthReview?
    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview?
}

extension WeeklyReviewServing {
    func getLatestCompletedWeeklyReview() async -> WeeklyHealthReview? {
        await getLatestCompletedWeeklyReview(calendar: .current)
    }

    func getWeeklyReview(for weekStartDate: Date) async -> WeeklyHealthReview? {
        await getWeeklyReview(for: weekStartDate, calendar: .current)
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool = false,
        allowPreview: Bool = false
    ) async -> WeeklyHealthReview? {
        await generateWeeklyReview(
            for: weekStartDate,
            forceRefresh: forceRefresh,
            allowPreview: allowPreview,
            calendar: .current
        )
    }
}

struct NoOpWeeklyReviewService: WeeklyReviewServing {
    func getLatestCompletedWeeklyReview(calendar: Calendar) async -> WeeklyHealthReview? { nil }

    func getWeeklyReview(for weekStartDate: Date, calendar: Calendar) async -> WeeklyHealthReview? {
        nil
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        nil
    }
}

struct WeeklyReviewService: WeeklyReviewServing {

    private let contextBuilder: any HealthIntelligenceContextBuilding
    private let weeklyReviewEngine: any WeeklyReviewProviding
    private let recoveryEngine: any RecoveryEngineProviding
    private let trainingLoadEngine: any TrainingLoadProviding
    private let cacheStore: any HealthCacheStore
    private let clock: any HealthIntelligenceClockProviding
    private let enginesEnabled: Bool

    init(
        contextBuilder: any HealthIntelligenceContextBuilding,
        weeklyReviewEngine: any WeeklyReviewProviding = WeeklyReviewEngine(),
        recoveryEngine: any RecoveryEngineProviding = RecoveryEngine(),
        trainingLoadEngine: any TrainingLoadProviding = TrainingLoadEngine(),
        cacheStore: any HealthCacheStore,
        clock: any HealthIntelligenceClockProviding = SystemHealthIntelligenceClockProvider(),
        enginesEnabled: Bool = HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled
    ) {
        self.contextBuilder = contextBuilder
        self.weeklyReviewEngine = weeklyReviewEngine
        self.recoveryEngine = recoveryEngine
        self.trainingLoadEngine = trainingLoadEngine
        self.cacheStore = cacheStore
        self.clock = clock
        self.enginesEnabled = enginesEnabled
    }

    func getLatestCompletedWeeklyReview(calendar: Calendar = .current) async -> WeeklyHealthReview? {
        guard enginesEnabled else { return nil }

        let referenceDate = clock.now()
        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            return nil
        }

        return await getWeeklyReview(for: weekStart, calendar: calendar)
    }

    func getWeeklyReview(
        for weekStartDate: Date,
        calendar: Calendar = .current
    ) async -> WeeklyHealthReview? {
        guard enginesEnabled else { return nil }

        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(weekStartDate, calendar: calendar) else {
            return nil
        }

        let referenceDate = clock.now()
        let isCompleted = WeeklyReviewWeekPolicy.isWeekCompleted(
            weekStart: weekStart,
            referenceDate: referenceDate,
            calendar: calendar
        )

        guard isCompleted else { return nil }

        if let cached = cacheStore.weeklyReview(for: weekStart, calendar: calendar),
           WeeklyReviewWeekPolicy.weekStartMatches(cached, weekStart: weekStart, calendar: calendar) {
            return cached
        }

        return await generateWeeklyReview(
            for: weekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool = false,
        calendar: Calendar = .current
    ) async -> WeeklyHealthReview? {
        guard enginesEnabled else { return nil }

        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(weekStartDate, calendar: calendar),
              let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            return nil
        }

        let referenceDate = clock.now()
        let isCompleted = WeeklyReviewWeekPolicy.isWeekCompleted(
            weekStart: weekStart,
            referenceDate: referenceDate,
            calendar: calendar
        )

        guard isCompleted || allowPreview else { return nil }

        if !forceRefresh,
           isCompleted,
           let cached = cacheStore.weeklyReview(for: weekStart, calendar: calendar),
           WeeklyReviewWeekPolicy.weekStartMatches(cached, weekStart: weekStart, calendar: calendar) {
            return cached
        }

        let composeEndDate: Date
        if isCompleted {
            composeEndDate = weekEnd
        } else {
            composeEndDate = calendar.startOfDay(for: referenceDate)
        }

        guard let review = await composeReview(weekEndDate: composeEndDate, calendar: calendar) else {
            return nil
        }

        guard WeeklyReviewWeekPolicy.weekStartMatches(review, weekStart: weekStart, calendar: calendar) else {
            return review
        }

        if isCompleted {
            cacheStore.storeWeeklyReview(review, calendar: calendar)
        }

        return review
    }

    // MARK: - Composition

    private func composeReview(
        weekEndDate: Date,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        let generatedAt = clock.now()
        let context = await contextBuilder.buildContext(for: weekEndDate, calendar: calendar)
        guard let weeklyContext = context.weeklyReviewContext else { return nil }

        guard weeklyContext.hasEnoughActivity else {
            return nil
        }

        let recoverySummaries = HealthIntelligenceWeeklyReviewSupport.recoverySummariesForWeek(
            weekContext: weeklyContext,
            metrics: context.metricsLast28Days,
            workouts: context.workoutsLast28Days,
            sleepRecords: context.sleepRecords,
            heartMetrics: context.heartMetrics,
            baselineContext: context.baselineContext,
            recoveryProvider: recoveryEngine,
            trainingLoadProvider: trainingLoadEngine,
            calendar: calendar
        )

        if let input = context.weeklyReviewInput(
            recoverySummaries: recoverySummaries,
            generatedAt: generatedAt
        ), let review = evaluateWeeklyReview(input) {
            return review
        }

        return baselineWeeklyReview(from: context)
    }

    private func evaluateWeeklyReview(_ input: WeeklyReviewEngineInput) -> WeeklyHealthReview? {
        do {
            return try weeklyReviewEngine.evaluate(input)
        } catch {
            HealthIntelligenceEngineLogger.sectionFailure(.weeklyReview, error: error)
            return nil
        }
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
