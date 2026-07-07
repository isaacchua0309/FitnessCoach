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
        let healthConnection = HealthIntelligenceSectionLoaderCore.journeyHealthConnection(
            isAppleHealthConnected: isAppleHealthConnected,
            availability: availability,
            todaySnapshot: todaySnapshot
        )

        guard healthConnection == .connected else {
            return JourneyHealthIntelligenceBuildInput(
                todaySnapshot: todaySnapshot,
                healthConnection: .notConnected,
                availability: availability,
                cachedDayCount: availability.cachedDayCount
            )
        }

        let recoveryDays = await loadRecoveryDays(
            referenceDate: referenceDate,
            dayCount: recoveryTimelineDayCount,
            todaySnapshot: todaySnapshot,
            snapshotProvider: snapshotProvider,
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
            ? await HealthIntelligenceSectionLoaderCore.loadWeeklyReview(
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
            availability: availability,
            cachedDayCount: availability.cachedDayCount,
            recoveryTimelineDayCount: recoveryTimelineDayCount
        )
    }

    // MARK: - Recovery

    private static func loadRecoveryDays(
        referenceDate: Date,
        dayCount: Int,
        todaySnapshot: HealthIntelligenceSnapshot?,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        cacheStore: any HealthCacheStore,
        enginesEnabled: Bool,
        calendar: Calendar
    ) async -> [JourneyHealthIntelligenceRecoveryDayInput] {
        let endDay = calendar.startOfDay(for: referenceDate)
        var recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput] = []

        // Inclusive span of `dayCount` days ending on referenceDate (today = offset 0).
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

            guard let snapshot = await snapshotProvider.loadSnapshot(
                for: day,
                mode: .preview,
                calendar: calendar
            ) else {
                continue
            }
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
        // Exclusive lookback: workouts from `windowDays` before endDay through end of reference day.
        let startDay = JourneyLogMetrics.lookbackStart(
            endingOn: referenceDate,
            dayCount: windowDays,
            calendar: calendar
        )
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
