//
//  JourneyHealthIntelligenceSectionLoader.swift
//  Fitness Coach
//
//  Forma — Loads Health Intelligence inputs for Journey presentation.
//

import Foundation

enum JourneyHealthIntelligenceSectionLoader {

    private static let defaultRecoveryDayCount = 7
    private static let defaultWorkoutWindowDays = 30

    static func loadInput(
        referenceDate: Date = Date(),
        isAppleHealthConnected: Bool,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        weeklyReviewProvider: any WeeklyReviewServing = NoOpWeeklyReviewService(),
        engine: any HealthIntelligenceEngineing,
        cacheStore: any HealthCacheStore,
        healthActivityQuery: HealthActivityQueryService,
        healthDataRepository: any HealthDataRepositorying,
        forceWeeklyReviewRefresh: Bool = false,
        enginesEnabled: Bool = HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled,
        weeklyReviewEnabled: Bool = HealthIntelligenceFeatureFlags.healthIntelligenceWeeklyReviewEnabled,
        recoveryTimelineDayCount: Int = defaultRecoveryDayCount,
        workoutHistoryWindowDays: Int = defaultWorkoutWindowDays,
        calendar: Calendar = .current
    ) async -> JourneyHealthIntelligenceBuildInput {
        let availability = await healthDataRepository.getHealthDataAvailability()
        let todaySnapshot = await snapshotProvider.loadTodaySnapshot(
            for: referenceDate,
            calendar: calendar
        )
        let healthConnection = resolveHealthConnection(
            isAppleHealthConnected: isAppleHealthConnected,
            availability: availability,
            todaySnapshot: todaySnapshot
        )

        guard healthConnection == .connected else {
            return JourneyHealthIntelligenceBuildInput(healthConnection: .notConnected)
        }

        let recoveryDays = await loadRecoveryDays(
            referenceDate: referenceDate,
            dayCount: recoveryTimelineDayCount,
            todaySnapshot: todaySnapshot,
            engine: engine,
            cacheStore: cacheStore,
            enginesEnabled: enginesEnabled,
            calendar: calendar
        )
        let workoutRecords = await loadWorkoutRecords(
            referenceDate: referenceDate,
            windowDays: workoutHistoryWindowDays,
            healthActivityQuery: healthActivityQuery,
            calendar: calendar
        )
        let weeklyReview = weeklyReviewEnabled
            ? await loadWeeklyReview(
                referenceDate: referenceDate,
                provider: weeklyReviewProvider,
                forceRefresh: forceWeeklyReviewRefresh,
                calendar: calendar
            )
            : nil

        return JourneyHealthIntelligenceBuildInput(
            todaySnapshot: todaySnapshot,
            recoveryDays: recoveryDays,
            workoutRecords: workoutRecords,
            weeklyReview: weeklyReview,
            planProgress: planProgress(from: weeklyReview),
            healthConnection: .connected,
            recoveryTimelineDayCount: recoveryTimelineDayCount
        )
    }

    // MARK: - Weekly review

    private static func loadWeeklyReview(
        referenceDate: Date,
        provider: any WeeklyReviewServing,
        forceRefresh: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        if forceRefresh,
           let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
               referenceDate: referenceDate,
               calendar: calendar
           ) {
            return await provider.generateWeeklyReview(
                for: weekStart,
                forceRefresh: true,
                allowPreview: false,
                calendar: calendar
            )
        }

        return await provider.getLatestCompletedWeeklyReview(calendar: calendar)
    }

    // MARK: - Recovery

    private static func loadRecoveryDays(
        referenceDate: Date,
        dayCount: Int,
        todaySnapshot: HealthIntelligenceSnapshot?,
        engine: any HealthIntelligenceEngineing,
        cacheStore: any HealthCacheStore,
        enginesEnabled: Bool,
        calendar: Calendar
    ) async -> [JourneyHealthIntelligenceRecoveryDayInput] {
        let endDay = calendar.startOfDay(for: referenceDate)
        var recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput] = []

        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                continue
            }
            let day = calendar.startOfDay(for: date)

            if offset == 0, let todaySnapshot, calendar.isDate(todaySnapshot.date, inSameDayAs: day) {
                recoveryDays.append(
                    recoveryDayInput(from: todaySnapshot)
                )
                continue
            }

            if let cachedSnapshot = cacheStore.intelligenceSnapshot(for: day, calendar: calendar) {
                recoveryDays.append(recoveryDayInput(from: cachedSnapshot))
                continue
            }

            if let cachedRecovery = cacheStore.recoverySummary(for: day, calendar: calendar) {
                recoveryDays.append(
                    JourneyHealthIntelligenceRecoveryDayInput(
                        date: day,
                        recovery: cachedRecovery,
                        steps: nil
                    )
                )
                continue
            }

            guard enginesEnabled else { continue }

            let snapshot = await engine.composeSnapshot(
                for: day,
                calendar: calendar,
                mode: .preview
            )
            cacheStore.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)
            recoveryDays.append(recoveryDayInput(from: snapshot))
        }

        return recoveryDays
    }

    private static func recoveryDayInput(
        from snapshot: HealthIntelligenceSnapshot
    ) -> JourneyHealthIntelligenceRecoveryDayInput {
        JourneyHealthIntelligenceRecoveryDayInput(
            date: snapshot.date,
            recovery: snapshot.recovery,
            steps: snapshot.activity.steps
        )
    }

    // MARK: - Workouts

    private static func loadWorkoutRecords(
        referenceDate: Date,
        windowDays: Int,
        healthActivityQuery: HealthActivityQueryService,
        calendar: Calendar
    ) async -> [JourneyHealthIntelligenceWorkoutRecordInput] {
        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -windowDays, to: endDay) ?? endDay
        let queryEnd = calendar.date(byAdding: .day, value: 1, to: endDay) ?? referenceDate

        let records = await healthActivityQuery.workouts(from: startDay, to: queryEnd)
        return records.map(workoutRecordInput(from:))
    }

    private static func workoutRecordInput(
        from record: HealthWorkoutRecord
    ) -> JourneyHealthIntelligenceWorkoutRecordInput {
        JourneyHealthIntelligenceWorkoutRecordInput(
            id: record.id.uuidString,
            date: record.startDate,
            title: record.activityName,
            durationMinutes: record.durationMinutes,
            activeCalories: record.activeCalories
        )
    }

    // MARK: - Connection

    private static func resolveHealthConnection(
        isAppleHealthConnected: Bool,
        availability: HealthDataAvailability,
        todaySnapshot: HealthIntelligenceSnapshot?
    ) -> JourneyHealthConnectionState {
        if let todaySnapshot,
           todaySnapshot.nextBestAction.reason == .connectHealth,
           !todaySnapshot.nextBestAction.id.isEmpty {
            return .notConnected
        }

        if isAppleHealthConnected || availability.hasAnyReadableSignal {
            return .connected
        }

        return .notConnected
    }

    private static func planProgress(
        from review: WeeklyHealthReview?
    ) -> JourneyHealthIntelligencePlanProgressInput? {
        guard let review else { return nil }
        return JourneyHealthIntelligencePlanProgressInput(
            proteinHitDays: review.stats.proteinHitDays,
            loggingConsistencyDays: review.stats.loggingConsistencyDays,
            weightChangeKg: review.stats.weightChangeKg,
            averageSteps: review.stats.averageSteps,
            totalWorkouts: review.stats.totalWorkouts
        )
    }
}
