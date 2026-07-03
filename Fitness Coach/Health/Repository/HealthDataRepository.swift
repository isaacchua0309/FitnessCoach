//
//  HealthDataRepository.swift
//  Fitness Coach
//
//  Forma — Repository boundary for normalized Health Intelligence data.
//
//  Architecture notes:
//  - Raw HealthKit samples (HKSample, statistics handles) are never persisted. They are
//    fetched, normalized into stable domain models, and discarded to limit PHI surface
//    area, keep cache size bounded, and avoid schema coupling to HealthKit revisions.
//  - UI should eventually consume `HealthIntelligenceSnapshot` (composed by
//    `HealthIntelligenceEngine`) rather than reading HealthKit or repository aggregates
//    directly. Snapshots are deterministic, testable, and decouple presentation from sync.
//  - Partial Health permissions are valid: each signal is fetched independently so denied
//    workout access does not discard available step counts for the same day.
//

import Foundation

enum HealthDataRepositoryError: Error, Equatable, Sendable {
    case unavailable
    case permissionDenied
    case fetchFailed
}

protocol HealthDataRepositorying: Sendable {
    func normalizedSamples(
        for date: Date,
        calendar: Calendar
    ) async throws -> [HealthNormalizedSample]

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics
    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics]
    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout]
    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout]
    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord]
    func getSleepRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [NormalizedSleepRecord]
    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric]
    func getHeartMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [NormalizedHeartMetric]
    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass]
    func getHealthDataAvailability() async -> HealthDataAvailability
    func refreshHealthData(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) async -> HealthRefreshResult
}

extension HealthDataRepositorying {
    func normalizedSamples(for date: Date) async throws -> [HealthNormalizedSample] {
        try await normalizedSamples(for: date, calendar: .current)
    }

    func getDailyMetrics(for date: Date) async -> DailyHealthMetrics {
        await getDailyMetrics(for: date, calendar: .current)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date) async -> [DailyHealthMetrics] {
        await getDailyMetrics(from: startDate, to: endDate, calendar: .current)
    }

    func getRecentWorkouts(days: Int = HealthDataRepositoryDefaults.recentWorkoutsDays) async -> [NormalizedWorkout] {
        await getRecentWorkouts(days: days, calendar: .current)
    }

    func getWorkouts(from startDate: Date, to endDate: Date) async -> [NormalizedWorkout] {
        await getWorkouts(from: startDate, to: endDate, calendar: .current)
    }

    func getRecentSleep(days: Int = HealthDataRepositoryDefaults.recentSleepDays) async -> [NormalizedSleepRecord] {
        await getRecentSleep(days: days, calendar: .current)
    }

    func getSleepRecords(from startDate: Date, to endDate: Date) async -> [NormalizedSleepRecord] {
        await getSleepRecords(from: startDate, to: endDate, calendar: .current)
    }

    func getRecentHeartMetrics(
        days: Int = HealthDataRepositoryDefaults.recentHeartMetricsDays
    ) async -> [NormalizedHeartMetric] {
        await getRecentHeartMetrics(days: days, calendar: .current)
    }

    func getHeartMetrics(from startDate: Date, to endDate: Date) async -> [NormalizedHeartMetric] {
        await getHeartMetrics(from: startDate, to: endDate, calendar: .current)
    }

    func getBodyMassHistory(
        days: Int = HealthDataRepositoryDefaults.bodyMassHistoryDays
    ) async -> [NormalizedBodyMass] {
        await getBodyMassHistory(days: days, calendar: .current)
    }

    func refreshHealthData(
        days: Int = HealthDataRepositoryDefaults.refreshDays,
        endingOn date: Date = Date()
    ) async -> HealthRefreshResult {
        await refreshHealthData(days: days, endingOn: date, calendar: .current)
    }
}

struct HealthDataRepository: HealthDataRepositorying {

    private let healthKitManager: any HealthKitManaging
    private let normalizer: any HealthSampleNormalizing
    private let cacheStore: any HealthCacheStore

    init(
        healthKitManager: any HealthKitManaging = HealthKitManager(),
        normalizer: any HealthSampleNormalizing = HealthSampleNormalizer(),
        cacheStore: any HealthCacheStore = LocalHealthCacheStore()
    ) {
        self.healthKitManager = healthKitManager
        self.normalizer = normalizer
        self.cacheStore = cacheStore
    }

    // MARK: - Legacy bridge

    func normalizedSamples(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> [HealthNormalizedSample] {
        guard healthKitManager.isHealthDataAvailable else {
            throw HealthDataRepositoryError.unavailable
        }

        let bundle = await loadDayBundle(for: date, calendar: calendar)
        return samples(from: bundle, calendar: calendar)
    }

    // MARK: - Daily metrics

    func getDailyMetrics(
        for date: Date,
        calendar: Calendar = .current
    ) async -> DailyHealthMetrics {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn(
                "getDailyMetrics unavailable",
                fields: ["date": Self.isoDay(date, calendar: calendar)]
            )
            return .empty(for: calendar.startOfDay(for: date))
        }

        let bundle = await loadDayBundle(for: date, calendar: calendar)
        return bundle.dailyMetrics
    }

    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async -> [DailyHealthMetrics] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getDailyMetrics range unavailable")
            return []
        }

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        guard rangeStart <= rangeEnd else {
            return []
        }

        var daysInRange: [Date] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            daysInRange.append(calendar.startOfDay(for: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        var metricsByDay: [Date: DailyHealthMetrics] = [:]
        var missingDays: [Date] = []
        metricsByDay.reserveCapacity(daysInRange.count)

        for day in daysInRange {
            if let cached = cacheStore.entry(for: day, calendar: calendar) {
                metricsByDay[day] = cached.bundle.dailyMetrics
            } else {
                missingDays.append(day)
            }
        }

        if !missingDays.isEmpty,
           let fetchStart = missingDays.first,
           let fetchEnd = missingDays.last {
            let fetched = await fetchDailyMetricsRange(
                from: fetchStart,
                to: fetchEnd,
                calendar: calendar
            )
            for metric in fetched {
                let day = calendar.startOfDay(for: metric.date)
                metricsByDay[day] = metric
            }
        }

        return daysInRange.map { day in
            metricsByDay[day] ?? .empty(for: day)
        }
    }

    // MARK: - Workouts

    func getRecentWorkouts(
        days: Int,
        calendar: Calendar = .current
    ) async -> [NormalizedWorkout] {
        let dayCount = HealthDataRepositoryDefaults.resolvedDays(
            days,
            default: HealthDataRepositoryDefaults.recentWorkoutsDays
        )
        let range = Self.recentDateRange(
            days: dayCount,
            endingOn: Date(),
            calendar: calendar
        )
        return await getWorkouts(from: range.start, to: range.end)
    }

    func getWorkouts(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async -> [NormalizedWorkout] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getWorkouts unavailable")
            return []
        }

        let range = Self.queryDateRange(from: startDate, to: endDate, calendar: calendar)
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)

        if shouldServeAggregateFromCache(
            aggregate: .workouts,
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        ) {
            let cached = cacheStore.workouts(from: range.start, to: inclusiveEnd, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getWorkouts cache hit",
                fields: ["count": String(cached.count)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchWorkouts(from: range.start, to: range.end)
            let workouts = normalizer.normalizeWorkouts(raw)
            cacheStore.upsertWorkouts(workouts, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getWorkouts refreshed",
                fields: [
                    "count": String(workouts.count),
                    "start": Self.isoDay(range.start, calendar: calendar),
                    "end": Self.isoDay(inclusiveEnd, calendar: calendar)
                ]
            )
            return workouts
        } catch {
            let cached = cacheStore.workouts(from: range.start, to: inclusiveEnd, calendar: calendar)
            if !cached.isEmpty {
                HealthDataRepositoryLogger.event(
                    "getWorkouts stale cache fallback",
                    fields: ["count": String(cached.count)]
                )
                return cached
            }
            logGracefulFetchFailure(context: "getWorkouts", error: error)
            return []
        }
    }

    // MARK: - Sleep

    func getRecentSleep(
        days: Int,
        calendar: Calendar = .current
    ) async -> [NormalizedSleepRecord] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getRecentSleep unavailable")
            return []
        }

        let dayCount = HealthDataRepositoryDefaults.resolvedDays(
            days,
            default: HealthDataRepositoryDefaults.recentSleepDays
        )
        let range = Self.recentDateRange(
            days: dayCount,
            endingOn: Date(),
            calendar: calendar
        )
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)

        if shouldServeAggregateFromCache(
            aggregate: .sleep,
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        ) {
            let cached = cacheStore.sleepRecords(from: range.start, to: inclusiveEnd, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getRecentSleep cache hit",
                fields: ["count": String(cached.count), "days": String(dayCount)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchSleepRecords(from: range.start, to: range.end)
            let records = normalizer.normalizeSleepRecords(raw)
            cacheStore.upsertSleepRecords(records, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getRecentSleep refreshed",
                fields: ["count": String(records.count), "days": String(dayCount)]
            )
            return records
        } catch {
            let cached = cacheStore.sleepRecords(from: range.start, to: inclusiveEnd, calendar: calendar)
            if !cached.isEmpty {
                return cached
            }
            logGracefulFetchFailure(context: "getRecentSleep", error: error)
            return []
        }
    }

    func getSleepRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async -> [NormalizedSleepRecord] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getSleepRecords unavailable")
            return []
        }

        let range = Self.queryDateRange(from: startDate, to: endDate, calendar: calendar)
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)

        if shouldServeAggregateFromCache(
            aggregate: .sleep,
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        ) {
            let cached = cacheStore.sleepRecords(from: range.start, to: inclusiveEnd, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getSleepRecords cache hit",
                fields: ["count": String(cached.count)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchSleepRecords(from: range.start, to: range.end)
            let records = normalizer.normalizeSleepRecords(raw)
            cacheStore.upsertSleepRecords(records, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getSleepRecords refreshed",
                fields: [
                    "count": String(records.count),
                    "start": Self.isoDay(range.start, calendar: calendar),
                    "end": Self.isoDay(inclusiveEnd, calendar: calendar)
                ]
            )
            return cacheStore.sleepRecords(from: range.start, to: inclusiveEnd, calendar: calendar)
        } catch {
            let cached = cacheStore.sleepRecords(from: range.start, to: inclusiveEnd, calendar: calendar)
            if !cached.isEmpty {
                return cached
            }
            logGracefulFetchFailure(context: "getSleepRecords", error: error)
            return []
        }
    }

    // MARK: - Heart metrics

    func getRecentHeartMetrics(
        days: Int,
        calendar: Calendar = .current
    ) async -> [NormalizedHeartMetric] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getRecentHeartMetrics unavailable")
            return []
        }

        let dayCount = HealthDataRepositoryDefaults.resolvedDays(
            days,
            default: HealthDataRepositoryDefaults.recentHeartMetricsDays
        )
        let range = Self.recentDateRange(
            days: dayCount,
            endingOn: Date(),
            calendar: calendar
        )
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)

        if shouldServeAggregateFromCache(
            aggregate: .heart,
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        ) {
            let cached = cacheStore.heartMetrics(from: range.start, to: inclusiveEnd, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getRecentHeartMetrics cache hit",
                fields: ["count": String(cached.count), "days": String(dayCount)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchHeartMetrics(from: range.start, to: range.end)
            let metrics = normalizer.normalizeHeartMetrics(raw)
            cacheStore.upsertHeartMetrics(metrics, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getRecentHeartMetrics refreshed",
                fields: ["count": String(metrics.count), "days": String(dayCount)]
            )
            return metrics
        } catch {
            let cached = cacheStore.heartMetrics(from: range.start, to: inclusiveEnd, calendar: calendar)
            if !cached.isEmpty {
                return cached
            }
            logGracefulFetchFailure(context: "getRecentHeartMetrics", error: error)
            return []
        }
    }

    func getHeartMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async -> [NormalizedHeartMetric] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getHeartMetrics unavailable")
            return []
        }

        let range = Self.queryDateRange(from: startDate, to: endDate, calendar: calendar)
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)

        if shouldServeAggregateFromCache(
            aggregate: .heart,
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        ) {
            let cached = cacheStore.heartMetrics(from: range.start, to: inclusiveEnd, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getHeartMetrics cache hit",
                fields: ["count": String(cached.count)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchHeartMetrics(from: range.start, to: range.end)
            let metrics = normalizer.normalizeHeartMetrics(raw)
            cacheStore.upsertHeartMetrics(metrics, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getHeartMetrics refreshed",
                fields: [
                    "count": String(metrics.count),
                    "start": Self.isoDay(range.start, calendar: calendar),
                    "end": Self.isoDay(inclusiveEnd, calendar: calendar)
                ]
            )
            return cacheStore.heartMetrics(from: range.start, to: inclusiveEnd, calendar: calendar)
        } catch {
            let cached = cacheStore.heartMetrics(from: range.start, to: inclusiveEnd, calendar: calendar)
            if !cached.isEmpty {
                return cached
            }
            logGracefulFetchFailure(context: "getHeartMetrics", error: error)
            return []
        }
    }

    // MARK: - Body mass

    func getBodyMassHistory(
        days: Int,
        calendar: Calendar = .current
    ) async -> [NormalizedBodyMass] {
        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("getBodyMassHistory unavailable")
            return []
        }

        let dayCount = HealthDataRepositoryDefaults.resolvedDays(
            days,
            default: HealthDataRepositoryDefaults.bodyMassHistoryDays
        )
        let range = Self.recentDateRange(
            days: dayCount,
            endingOn: Date(),
            calendar: calendar
        )
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)
        let cached = cacheStore.bodyMassRecords(from: range.start, to: inclusiveEnd, calendar: calendar)

        if !cached.isEmpty,
           shouldServeAggregateFromCache(
               aggregate: .bodyMass,
               from: range.start,
               to: inclusiveEnd,
               calendar: calendar
           ) {
            HealthDataRepositoryLogger.event(
                "getBodyMassHistory cache hit",
                fields: ["count": String(cached.count), "days": String(dayCount)]
            )
            return cached
        }

        do {
            let raw = try await healthKitManager.fetchBodyMassRecords(from: range.start, to: range.end)
            let records = normalizer.normalizeBodyMassRecords(raw)
            cacheStore.upsertBodyMassRecords(records, calendar: calendar)
            HealthDataRepositoryLogger.event(
                "getBodyMassHistory refreshed",
                fields: ["count": String(records.count), "days": String(dayCount)]
            )
            return records
        } catch {
            if !cached.isEmpty {
                return cached
            }
            logGracefulFetchFailure(context: "getBodyMassHistory", error: error)
            return []
        }
    }

    // MARK: - Availability & refresh

    func getHealthDataAvailability() async -> HealthDataAvailability {
        await getHealthDataAvailability(calendar: .current)
    }

    private func getHealthDataAvailability(calendar: Calendar) async -> HealthDataAvailability {
        let permissionStatus = await healthKitManager.getAuthorizationStatus()
        let availability = HealthDataAvailability(
            isHealthDataAvailable: healthKitManager.isHealthDataAvailable,
            permissionStatus: permissionStatus,
            cachedDayCount: cacheStore.cachedDayCount(calendar: calendar)
        )
        HealthDataRepositoryLogger.event(
            "getHealthDataAvailability",
            fields: [
                "healthDataAvailable": String(availability.isHealthDataAvailable),
                "cachedDayCount": String(availability.cachedDayCount),
                "readableSignals": String(availability.permissionStatus.availableSignals.count)
            ]
        )
        return availability
    }

    func refreshHealthData(
        days: Int,
        endingOn date: Date = Date(),
        calendar: Calendar = .current
    ) async -> HealthRefreshResult {
        let dayCount = HealthDataRepositoryDefaults.resolvedDays(
            days,
            default: HealthDataRepositoryDefaults.refreshDays
        )

        guard healthKitManager.isHealthDataAvailable else {
            HealthDataRepositoryLogger.warn("refreshHealthData unavailable")
            return HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
        }

        let refreshed: Int
        if dayCount > 1 {
            refreshed = await refreshHealthDataBulk(
                days: dayCount,
                endingOn: date,
                calendar: calendar
            )
        } else {
            refreshed = await refreshHealthDataSingleDay(
                endingOn: date,
                calendar: calendar
            )
        }

        HealthDataRepositoryLogger.event(
            "refreshHealthData",
            fields: [
                "daysRefreshed": String(refreshed),
                "requestedDays": String(dayCount),
                "bulk": String(dayCount > 1)
            ]
        )

        return HealthRefreshResult(daysRefreshed: refreshed, refreshedAt: Date())
    }

    // MARK: - Private

    private func loadDayBundle(
        for date: Date,
        calendar: Calendar,
        forceRefresh: Bool = false
    ) async -> HealthNormalizedDayBundle {
        let (bundle, _) = await loadDayBundleWithFetchStatus(
            for: date,
            calendar: calendar,
            forceRefresh: forceRefresh
        )
        return bundle
    }

    private func loadDayBundleWithFetchStatus(
        for date: Date,
        calendar: Calendar,
        forceRefresh: Bool = false
    ) async -> (bundle: HealthNormalizedDayBundle, fetchedFromHealthKit: Bool) {
        let dayStart = calendar.startOfDay(for: date)

        if !forceRefresh,
           let cached = cacheStore.entry(for: dayStart, calendar: calendar),
           cacheStore.isFresh(cachedAt: cached.cachedAt, for: dayStart, calendar: calendar) {
            HealthDataRepositoryLogger.event(
                "cache hit",
                fields: ["date": Self.isoDay(dayStart, calendar: calendar)]
            )
            return (cached.bundle, false)
        }

        guard healthKitManager.isHealthDataAvailable else {
            return (.empty(for: dayStart, calendar: calendar), false)
        }

        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return (.empty(for: dayStart, calendar: calendar), false)
        }

        let raw = await fetchRawDayInput(
            dayStart: dayStart,
            dayEnd: dayEnd,
            calendar: calendar
        )
        let bundle = normalizer.normalize(day: raw, calendar: calendar)
        cacheStore.store(
            HealthCacheEntry(date: dayStart, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )
        HealthDataRepositoryLogger.event(
            "cached day bundle",
            fields: [
                "date": Self.isoDay(dayStart, calendar: calendar),
                "workouts": String(bundle.workouts.count),
                "sleep": String(bundle.sleepRecords.count)
            ]
        )
        return (bundle, true)
    }

    private func refreshHealthDataSingleDay(
        endingOn date: Date,
        calendar: Calendar
    ) async -> Int {
        let (_, fetched) = await loadDayBundleWithFetchStatus(
            for: date,
            calendar: calendar,
            forceRefresh: true
        )
        return fetched ? 1 : 0
    }

    private func refreshHealthDataBulk(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) async -> Int {
        let range = Self.recentDateRange(days: days, endingOn: date, calendar: calendar)
        let inclusiveEnd = Self.inclusiveEndDay(for: range.end, calendar: calendar)
        let allDays = Self.daysInRange(from: range.start, to: inclusiveEnd, calendar: calendar)
        guard !allDays.isEmpty else { return 0 }

        cacheStore.beginBatchWrite()
        defer { cacheStore.endBatchWrite(calendar: calendar) }

        let cachedAt = Date()
        var bundlesByDay: [Date: HealthNormalizedDayBundle] = [:]
        bundlesByDay.reserveCapacity(allDays.count)

        let metricsList = await fetchDailyMetricsRange(
            from: range.start,
            to: inclusiveEnd,
            calendar: calendar
        )
        for metric in metricsList {
            let day = calendar.startOfDay(for: metric.date)
            bundlesByDay[day] = HealthNormalizedDayBundle(
                dailyMetrics: metric,
                workouts: [],
                sleepRecords: [],
                heartMetrics: [],
                bodyMassRecords: []
            )
        }

        for day in allDays where bundlesByDay[day] == nil {
            bundlesByDay[day] = .empty(for: day, calendar: calendar)
        }

        let workouts = normalizer.normalizeWorkouts(
            await fetchWorkoutsSafe(from: range.start, to: range.end)
        )
        if !workouts.isEmpty {
            cacheStore.upsertWorkouts(workouts, calendar: calendar)
            mergeWorkouts(workouts, into: &bundlesByDay, calendar: calendar)
        }

        let sleepRecords = normalizer.normalizeSleepRecords(
            await fetchSleepRecordsSafe(from: range.start, to: range.end)
        )
        if !sleepRecords.isEmpty {
            cacheStore.upsertSleepRecords(sleepRecords, calendar: calendar)
            mergeSleepRecords(sleepRecords, into: &bundlesByDay, calendar: calendar)
        }

        let heartMetrics = normalizer.normalizeHeartMetrics(
            await fetchHeartMetricsSafe(from: range.start, to: range.end)
        )
        if !heartMetrics.isEmpty {
            cacheStore.upsertHeartMetrics(heartMetrics, calendar: calendar)
            mergeHeartMetrics(heartMetrics, into: &bundlesByDay, calendar: calendar)
        }

        let bodyMassRecords = normalizer.normalizeBodyMassRecords(
            await fetchBodyMassRecordsSafe(from: range.start, to: range.end)
        )
        if !bodyMassRecords.isEmpty {
            cacheStore.upsertBodyMassRecords(bodyMassRecords, calendar: calendar)
            mergeBodyMassRecords(bodyMassRecords, into: &bundlesByDay, calendar: calendar)
        }

        var refreshedDays = 0
        for day in allDays {
            guard let bundle = bundlesByDay[day] else { continue }
            cacheStore.store(
                HealthCacheEntry(date: day, bundle: bundle, cachedAt: cachedAt),
                calendar: calendar
            )
            if bundle.hasAnySignalData {
                refreshedDays += 1
            }
        }

        if refreshedDays == 0, !metricsList.isEmpty {
            refreshedDays = allDays.count
        } else if refreshedDays == 0,
                  !workouts.isEmpty || !sleepRecords.isEmpty || !heartMetrics.isEmpty || !bodyMassRecords.isEmpty {
            refreshedDays = allDays.count
        }

        return refreshedDays
    }

    private func fetchRawDayInput(
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) async -> HealthRawDayInput {
        async let dailyMetrics = fetchDailyMetricsSafe(for: dayStart, calendar: calendar)
        async let workouts = fetchWorkoutsSafe(from: dayStart, to: dayEnd)
        async let sleepRecords = fetchSleepRecordsSafe(from: dayStart, to: dayEnd)
        async let heartMetrics = fetchHeartMetricsSafe(from: dayStart, to: dayEnd)
        async let bodyMassRecords = fetchBodyMassRecordsSafe(from: dayStart, to: dayEnd)

        return HealthRawDayInput(
            dailyMetrics: await dailyMetrics,
            workouts: await workouts,
            sleepRecords: await sleepRecords,
            heartMetrics: await heartMetrics,
            bodyMassRecords: await bodyMassRecords
        )
    }

    private func fetchDailyMetricsSafe(for date: Date, calendar: Calendar) async -> HealthDailyMetrics {
        do {
            return try await healthKitManager.fetchDailyMetrics(for: date, calendar: calendar)
        } catch {
            logGracefulFetchFailure(
                context: "fetchDailyMetrics",
                error: error,
                fields: ["date": Self.isoDay(date, calendar: calendar)]
            )
            return .empty(for: date)
        }
    }

    private func fetchWorkoutsSafe(from startDate: Date, to endDate: Date) async -> [HealthFetchedWorkout] {
        do {
            return try await healthKitManager.fetchWorkouts(from: startDate, to: endDate)
        } catch {
            logGracefulFetchFailure(context: "fetchWorkouts", error: error)
            return []
        }
    }

    private func fetchSleepRecordsSafe(from startDate: Date, to endDate: Date) async -> [HealthSleepRecord] {
        do {
            return try await healthKitManager.fetchSleepRecords(from: startDate, to: endDate)
        } catch {
            logGracefulFetchFailure(context: "fetchSleepRecords", error: error)
            return []
        }
    }

    private func fetchHeartMetricsSafe(from startDate: Date, to endDate: Date) async -> [HealthHeartMetric] {
        do {
            return try await healthKitManager.fetchHeartMetrics(from: startDate, to: endDate)
        } catch {
            logGracefulFetchFailure(context: "fetchHeartMetrics", error: error)
            return []
        }
    }

    private func fetchBodyMassRecordsSafe(from startDate: Date, to endDate: Date) async -> [HealthBodyMassRecord] {
        do {
            return try await healthKitManager.fetchBodyMassRecords(from: startDate, to: endDate)
        } catch {
            logGracefulFetchFailure(context: "fetchBodyMassRecords", error: error)
            return []
        }
    }

    private func mergeWorkouts(
        _ workouts: [NormalizedWorkout],
        into bundles: inout [Date: HealthNormalizedDayBundle],
        calendar: Calendar
    ) {
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startDate)
            let bundle = bundles[day] ?? .empty(for: day, calendar: calendar)
            let merged = normalizer.deduplicateWorkouts(bundle.workouts + [workout])
            bundles[day] = HealthNormalizedDayBundle(
                dailyMetrics: bundle.dailyMetrics,
                workouts: merged,
                sleepRecords: bundle.sleepRecords,
                heartMetrics: bundle.heartMetrics,
                bodyMassRecords: bundle.bodyMassRecords
            )
        }
    }

    private func mergeSleepRecords(
        _ records: [NormalizedSleepRecord],
        into bundles: inout [Date: HealthNormalizedDayBundle],
        calendar: Calendar
    ) {
        for record in records {
            let day = calendar.startOfDay(for: record.startDate)
            var bundle = bundles[day] ?? .empty(for: day, calendar: calendar)
            let merged = normalizer.deduplicateSleepRecords(bundle.sleepRecords + [record])
            bundles[day] = HealthNormalizedDayBundle(
                dailyMetrics: bundle.dailyMetrics,
                workouts: bundle.workouts,
                sleepRecords: merged,
                heartMetrics: bundle.heartMetrics,
                bodyMassRecords: bundle.bodyMassRecords
            )
        }
    }

    private func mergeHeartMetrics(
        _ metrics: [NormalizedHeartMetric],
        into bundles: inout [Date: HealthNormalizedDayBundle],
        calendar: Calendar
    ) {
        for metric in metrics {
            let day = calendar.startOfDay(for: metric.date)
            var bundle = bundles[day] ?? .empty(for: day, calendar: calendar)
            let merged = normalizer.deduplicateHeartMetrics(bundle.heartMetrics + [metric])
            bundles[day] = HealthNormalizedDayBundle(
                dailyMetrics: bundle.dailyMetrics,
                workouts: bundle.workouts,
                sleepRecords: bundle.sleepRecords,
                heartMetrics: merged,
                bodyMassRecords: bundle.bodyMassRecords
            )
        }
    }

    private func mergeBodyMassRecords(
        _ records: [NormalizedBodyMass],
        into bundles: inout [Date: HealthNormalizedDayBundle],
        calendar: Calendar
    ) {
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            var bundle = bundles[day] ?? .empty(for: day, calendar: calendar)
            let merged = normalizer.deduplicateBodyMassRecords(bundle.bodyMassRecords + [record])
            bundles[day] = HealthNormalizedDayBundle(
                dailyMetrics: bundle.dailyMetrics,
                workouts: bundle.workouts,
                sleepRecords: bundle.sleepRecords,
                heartMetrics: bundle.heartMetrics,
                bodyMassRecords: merged
            )
        }
    }

    private func fetchDailyMetricsRange(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        do {
            let raw = try await healthKitManager.fetchDailyMetrics(
                from: startDate,
                to: endDate,
                calendar: calendar
            )
            let normalized = raw.map { normalizer.normalizeDailyMetrics($0, calendar: calendar) }
            let cachedAt = Date()
            for metric in normalized {
                let day = calendar.startOfDay(for: metric.date)
                let existing = cacheStore.entry(for: day, calendar: calendar)?.bundle
                let bundle = HealthNormalizedDayBundle(
                    dailyMetrics: metric,
                    workouts: existing?.workouts ?? [],
                    sleepRecords: existing?.sleepRecords ?? [],
                    heartMetrics: existing?.heartMetrics ?? [],
                    bodyMassRecords: existing?.bodyMassRecords ?? []
                )
                cacheStore.store(
                    HealthCacheEntry(date: day, bundle: bundle, cachedAt: cachedAt),
                    calendar: calendar
                )
            }
            return normalized
        } catch {
            logGracefulFetchFailure(context: "fetchDailyMetricsRange", error: error)
            return []
        }
    }

    private func samples(
        from bundle: HealthNormalizedDayBundle,
        calendar: Calendar
    ) -> [HealthNormalizedSample] {
        var samples: [HealthNormalizedSample] = []
        let dayStart = calendar.startOfDay(for: bundle.dailyMetrics.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let metrics = bundle.dailyMetrics
        if metrics.steps > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .stepCount,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: Double(metrics.steps),
                    unitSymbol: HealthUnitSymbol.count
                )
            )
        }
        if metrics.activeEnergyKcal > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .activeEnergy,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: metrics.activeEnergyKcal,
                    unitSymbol: HealthUnitSymbol.kilocalorie
                )
            )
        }
        if metrics.exerciseMinutes > 0 {
            samples.append(
                HealthNormalizedSample(
                    kind: .exerciseTime,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: metrics.exerciseMinutes,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        for workout in bundle.workouts {
            samples.append(
                HealthNormalizedSample(
                    id: workout.id,
                    kind: .workout,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    value: Double(workout.durationMinutes),
                    unitSymbol: HealthUnitSymbol.minutes,
                    sourceBundleIdentifier: workout.sourceName
                )
            )
        }

        for metric in bundle.heartMetrics {
            let kind: HealthSampleKind = metric.kind == .restingHeartRate ? .restingHeartRate : .heartRate
            samples.append(
                HealthNormalizedSample(
                    id: metric.id,
                    kind: kind,
                    startDate: metric.date,
                    endDate: metric.date,
                    value: metric.value,
                    unitSymbol: metric.unitSymbol
                )
            )
        }

        for sleep in bundle.sleepRecords where sleep.asleepMinutes > 0 {
            samples.append(
                HealthNormalizedSample(
                    id: sleep.id,
                    kind: .sleep,
                    startDate: sleep.startDate,
                    endDate: sleep.endDate,
                    value: sleep.asleepMinutes,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        return normalizer.deduplicate(samples: samples)
    }

    private func logGracefulFetchFailure(
        context: String,
        error: Error,
        fields: [String: String] = [:]
    ) {
        let level = isExpectedHealthKitAccessFailure(error) ? "debug" : "warn"
        HealthDataRepositoryLogger.fetchFailure(
            context: context,
            underlying: error,
            fields: fields,
            level: level
        )
    }

    private func isExpectedHealthKitAccessFailure(_ error: Error) -> Bool {
        guard let healthKitError = error as? HealthKitManagerError else { return false }
        switch healthKitError {
        case .unavailable, .authorizationDenied:
            return true
        case .queryFailed:
            return false
        }
    }

    private static func daysInRange(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        guard rangeStart <= rangeEnd else { return [] }

        var days: [Date] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return days
    }

    private static func recentDateRange(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let endDay = calendar.startOfDay(for: date)
        let dayCount = max(days, 1)
        let startDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return (startDay, endExclusive)
    }

    private static func queryDateRange(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return (start, endExclusive)
    }

    private func shouldServeAggregateFromCache(
        aggregate: HealthCacheAggregateKind,
        from startDate: Date,
        to inclusiveEnd: Date,
        calendar: Calendar
    ) -> Bool {
        if cacheStore.dayCoverageIsFresh(from: startDate, to: inclusiveEnd, calendar: calendar) {
            return true
        }

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: inclusiveEnd)
        let isSingleDay = rangeStart == rangeEnd

        guard isSingleDay else {
            return false
        }

        guard let updatedAt = cacheStore.indexUpdatedAt(for: aggregate) else {
            return false
        }

        let today = calendar.startOfDay(for: Date())
        let rangeIncludesToday = today >= rangeStart && today <= rangeEnd
        let freshnessDate = rangeIncludesToday ? today : inclusiveEnd
        return cacheStore.isFresh(cachedAt: updatedAt, for: freshnessDate, calendar: calendar)
    }

    private static func inclusiveEndDay(for exclusiveEnd: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -1, to: exclusiveEnd)
            .map { calendar.startOfDay(for: $0) }
            ?? calendar.startOfDay(for: exclusiveEnd)
    }

    private static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}
