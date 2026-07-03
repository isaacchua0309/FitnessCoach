//
//  HealthCacheStore.swift
//  Fitness Coach
//
//  Forma — Protocol and in-memory implementation for normalized health cache.
//

import Foundation

struct HealthCacheEntry: Equatable, Sendable {
    let date: Date
    let bundle: HealthNormalizedDayBundle
    let cachedAt: Date
}

protocol HealthCacheStore: Sendable {

    // MARK: - Day bundles

    func entry(for date: Date, calendar: Calendar) -> HealthCacheEntry?
    func store(_ entry: HealthCacheEntry, calendar: Calendar)

    // MARK: - Typed record access

    func dailyMetrics(for date: Date, calendar: Calendar) -> DailyHealthMetrics?
    func workouts(from startDate: Date, to endDate: Date, calendar: Calendar) -> [WorkoutRecord]
    func sleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) -> [SleepRecord]
    func heartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) -> [HeartMetricRecord]
    func bodyMassRecords(from startDate: Date, to endDate: Date, calendar: Calendar) -> [BodyMassRecord]

    func upsertWorkouts(_ workouts: [WorkoutRecord], calendar: Calendar)
    func upsertSleepRecords(_ records: [SleepRecord], calendar: Calendar)
    func upsertHeartMetrics(_ metrics: [HeartMetricRecord], calendar: Calendar)
    func upsertBodyMassRecords(_ records: [BodyMassRecord], calendar: Calendar)

    // MARK: - Intelligence placeholders

    func recoverySummary(for date: Date, calendar: Calendar) -> RecoverySummary?
    func storeRecoverySummary(_ summary: RecoverySummary, for date: Date, calendar: Calendar)

    func intelligenceSnapshot(for date: Date, calendar: Calendar) -> HealthIntelligenceSnapshot?
    func intelligenceSnapshotEntry(for date: Date, calendar: Calendar) -> HealthIntelligenceSnapshotCacheEntry?
    func storeIntelligenceSnapshot(_ snapshot: HealthIntelligenceSnapshot, for date: Date, calendar: Calendar)
    func removeIntelligenceSnapshots(from startDay: Date, through endDay: Date, calendar: Calendar)

    func weeklyReview(for weekStartDate: Date, calendar: Calendar) -> WeeklyHealthReview?
    func storeWeeklyReview(_ review: WeeklyHealthReview, calendar: Calendar)

    // MARK: - Freshness & maintenance

    func isFresh(cachedAt: Date, for date: Date, calendar: Calendar) -> Bool
    func dayCoverageIsFresh(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> Bool
    func invalidate(through date: Date, calendar: Calendar)
    func pruneOldEntries(keepingLastDays: Int, calendar: Calendar)
    func cachedDayCount(calendar: Calendar) -> Int
    func indexUpdatedAt(for aggregate: HealthCacheAggregateKind) -> Date?
    func clearAll()

    // MARK: - Batch writes (defer disk index persistence during bulk sync)

    func beginBatchWrite()
    func endBatchWrite(calendar: Calendar)
}

extension HealthCacheStore {
    func beginBatchWrite() {}
    func endBatchWrite(calendar: Calendar) {}
    func isFresh(cachedAt: Date, for date: Date, calendar: Calendar = .current) -> Bool {
        HealthCachePolicy.isFresh(cachedAt: cachedAt, for: date, calendar: calendar)
    }
}

// MARK: - In-memory store

final class MemoryHealthCacheStore: HealthCacheStore, @unchecked Sendable {

    private var dayEntries: [Date: HealthCacheEntry] = [:]
    private var workoutsByID: [UUID: WorkoutRecord] = [:]
    private var sleepByID: [UUID: SleepRecord] = [:]
    private var heartByID: [UUID: HeartMetricRecord] = [:]
    private var bodyMassByID: [UUID: BodyMassRecord] = [:]
    private var recoveryByDay: [Date: (summary: RecoverySummary, cachedAt: Date)] = [:]
    private var snapshotsByDay: [Date: (snapshot: HealthIntelligenceSnapshot, cachedAt: Date)] = [:]
    private var weeklyReviewsByWeekStart: [Date: (review: WeeklyHealthReview, cachedAt: Date)] = [:]
    private var indexUpdatedAt: [HealthCacheAggregateKind: Date] = [:]
    private let lock = NSLock()

    func entry(for date: Date, calendar: Calendar = .current) -> HealthCacheEntry? {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        defer { lock.unlock() }
        return dayEntries[key]
    }

    func store(_ entry: HealthCacheEntry, calendar: Calendar = .current) {
        let key = calendar.startOfDay(for: entry.date)
        lock.lock()
        dayEntries[key] = entry
        mergeWorkouts(entry.bundle.workouts, calendar: calendar, locked: true)
        mergeSleep(entry.bundle.sleepRecords, calendar: calendar, locked: true)
        mergeHeart(entry.bundle.heartMetrics, calendar: calendar, locked: true)
        mergeBodyMass(entry.bundle.bodyMassRecords, calendar: calendar, locked: true)
        lock.unlock()
    }

    func dailyMetrics(for date: Date, calendar: Calendar = .current) -> DailyHealthMetrics? {
        entry(for: date, calendar: calendar)?.bundle.dailyMetrics
    }

    func workouts(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [WorkoutRecord] {
        let range = Self.inclusiveDayRange(from: startDate, to: endDate, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }
        return workoutsByID.values
            .filter { $0.startDate >= range.start && $0.startDate < range.endExclusive }
            .sorted { $0.startDate > $1.startDate }
    }

    func sleepRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [SleepRecord] {
        let range = Self.inclusiveDayRange(from: startDate, to: endDate, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }
        return sleepByID.values
            .filter { $0.startDate >= range.start && $0.startDate < range.endExclusive }
            .sorted { $0.startDate < $1.startDate }
    }

    func heartMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [HeartMetricRecord] {
        let range = Self.inclusiveDayRange(from: startDate, to: endDate, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }
        return heartByID.values
            .filter { $0.date >= range.start && $0.date < range.endExclusive }
            .sorted { $0.date < $1.date }
    }

    func bodyMassRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> [BodyMassRecord] {
        let range = Self.inclusiveDayRange(from: startDate, to: endDate, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }
        return bodyMassByID.values
            .filter { $0.date >= range.start && $0.date < range.endExclusive }
            .sorted { $0.date < $1.date }
    }

    func upsertWorkouts(_ workouts: [WorkoutRecord], calendar: Calendar = .current) {
        lock.lock()
        mergeWorkouts(workouts, calendar: calendar, locked: true)
        indexUpdatedAt[.workouts] = Date()
        lock.unlock()
    }

    func upsertSleepRecords(_ records: [SleepRecord], calendar: Calendar = .current) {
        lock.lock()
        mergeSleep(records, calendar: calendar, locked: true)
        indexUpdatedAt[.sleep] = Date()
        lock.unlock()
    }

    func upsertHeartMetrics(_ metrics: [HeartMetricRecord], calendar: Calendar = .current) {
        lock.lock()
        mergeHeart(metrics, calendar: calendar, locked: true)
        indexUpdatedAt[.heart] = Date()
        lock.unlock()
    }

    func upsertBodyMassRecords(_ records: [BodyMassRecord], calendar: Calendar = .current) {
        lock.lock()
        mergeBodyMass(records, calendar: calendar, locked: true)
        indexUpdatedAt[.bodyMass] = Date()
        lock.unlock()
    }

    func recoverySummary(for date: Date, calendar: Calendar = .current) -> RecoverySummary? {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        defer { lock.unlock() }
        return recoveryByDay[key]?.summary
    }

    func storeRecoverySummary(
        _ summary: RecoverySummary,
        for date: Date,
        calendar: Calendar = .current
    ) {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        recoveryByDay[key] = (summary, Date())
        lock.unlock()
    }

    func intelligenceSnapshot(for date: Date, calendar: Calendar = .current) -> HealthIntelligenceSnapshot? {
        intelligenceSnapshotEntry(for: date, calendar: calendar)?.snapshot
    }

    func intelligenceSnapshotEntry(for date: Date, calendar: Calendar = .current) -> HealthIntelligenceSnapshotCacheEntry? {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        defer { lock.unlock() }
        guard let stored = snapshotsByDay[key] else { return nil }
        return HealthIntelligenceSnapshotCacheEntry(
            snapshot: stored.snapshot,
            cachedAt: stored.cachedAt
        )
    }

    func storeIntelligenceSnapshot(
        _ snapshot: HealthIntelligenceSnapshot,
        for date: Date,
        calendar: Calendar = .current,
        cachedAt: Date = Date()
    ) {
        let key = calendar.startOfDay(for: date)
        lock.lock()
        snapshotsByDay[key] = (snapshot, cachedAt)
        lock.unlock()
    }

    func removeIntelligenceSnapshots(
        from startDay: Date,
        through endDay: Date,
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard start <= end else { return }

        lock.lock()
        let removedCount = snapshotsByDay.filter { key, _ in
            key >= start && key <= end
        }.count
        snapshotsByDay = snapshotsByDay.filter { key, _ in
            key < start || key > end
        }
        lock.unlock()

        if removedCount > 0 {
            HealthCacheStoreLogger.snapshotsRemoved(dayCount: removedCount)
        }
    }

    func weeklyReview(for weekStartDate: Date, calendar: Calendar = .current) -> WeeklyHealthReview? {
        let key = WeeklyReviewWeekPolicy.normalizedWeekStart(weekStartDate, calendar: calendar)
            ?? calendar.startOfDay(for: weekStartDate)
        lock.lock()
        defer { lock.unlock() }
        return weeklyReviewsByWeekStart[key]?.review
    }

    func storeWeeklyReview(_ review: WeeklyHealthReview, calendar: Calendar = .current) {
        let key = WeeklyReviewWeekPolicy.normalizedWeekStart(review.weekStartDate, calendar: calendar)
            ?? calendar.startOfDay(for: review.weekStartDate)
        lock.lock()
        weeklyReviewsByWeekStart[key] = (review, Date())
        lock.unlock()
    }

    func dayCoverageIsFresh(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let days = Self.days(from: startDate, to: endDate, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }

        for day in days {
            guard let entry = dayEntries[day],
                  HealthCachePolicy.isFresh(cachedAt: entry.cachedAt, for: day, calendar: calendar) else {
                return false
            }
        }
        return !days.isEmpty
    }

    func invalidate(through date: Date, calendar: Calendar = .current) {
        let cutoff = calendar.startOfDay(for: date)
        lock.lock()
        dayEntries = dayEntries.filter { $0.key >= cutoff }
        recoveryByDay = recoveryByDay.filter { $0.key >= cutoff }
        snapshotsByDay = snapshotsByDay.filter { $0.key >= cutoff }
        weeklyReviewsByWeekStart = weeklyReviewsByWeekStart.filter { $0.key >= cutoff }
        lock.unlock()
    }

    func pruneOldEntries(keepingLastDays: Int, calendar: Calendar = .current) {
        guard let cutoff = HealthCachePolicy.pruneCutoffDate(
            keepingLastDays: keepingLastDays,
            calendar: calendar
        ) else {
            return
        }

        lock.lock()
        dayEntries = dayEntries.filter { $0.key >= cutoff }
        recoveryByDay = recoveryByDay.filter { $0.key >= cutoff }
        snapshotsByDay = snapshotsByDay.filter { $0.key >= cutoff }
        weeklyReviewsByWeekStart = weeklyReviewsByWeekStart.filter { $0.key >= cutoff }
        workoutsByID = workoutsByID.filter { calendar.startOfDay(for: $0.value.startDate) >= cutoff }
        sleepByID = sleepByID.filter { calendar.startOfDay(for: $0.value.startDate) >= cutoff }
        heartByID = heartByID.filter { calendar.startOfDay(for: $0.value.date) >= cutoff }
        bodyMassByID = bodyMassByID.filter { calendar.startOfDay(for: $0.value.date) >= cutoff }
        lock.unlock()
    }

    func cachedDayCount(calendar: Calendar = .current) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return dayEntries.count
    }

    func indexUpdatedAt(for aggregate: HealthCacheAggregateKind) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return indexUpdatedAt[aggregate]
    }

    func clearAll() {
        lock.lock()
        dayEntries.removeAll()
        workoutsByID.removeAll()
        sleepByID.removeAll()
        heartByID.removeAll()
        bodyMassByID.removeAll()
        recoveryByDay.removeAll()
        snapshotsByDay.removeAll()
        weeklyReviewsByWeekStart.removeAll()
        indexUpdatedAt.removeAll()
        lock.unlock()
    }

    // MARK: - Private

    private func mergeWorkouts(
        _ workouts: [WorkoutRecord],
        calendar: Calendar,
        locked: Bool
    ) {
        if !locked { lock.lock() }
        for workout in workouts {
            workoutsByID[workout.id] = workout
        }
        if !locked { lock.unlock() }
    }

    private func mergeSleep(
        _ records: [SleepRecord],
        calendar: Calendar,
        locked: Bool
    ) {
        if !locked { lock.lock() }
        for record in records {
            sleepByID[record.id] = record
        }
        if !locked { lock.unlock() }
    }

    private func mergeHeart(
        _ metrics: [HeartMetricRecord],
        calendar: Calendar,
        locked: Bool
    ) {
        if !locked { lock.lock() }
        for metric in metrics {
            heartByID[metric.id] = metric
        }
        if !locked { lock.unlock() }
    }

    private func mergeBodyMass(
        _ records: [BodyMassRecord],
        calendar: Calendar,
        locked: Bool
    ) {
        if !locked { lock.lock() }
        for record in records {
            bodyMassByID[record.id] = record
        }
        if !locked { lock.unlock() }
    }

    private static func inclusiveDayRange(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) -> (start: Date, endExclusive: Date) {
        let start = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return (start, endExclusive)
    }

    private static func days(
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
}

// Production default pairs disk persistence with in-memory L1 via LocalHealthCacheStore.
// Tests should inject MemoryHealthCacheStore for speed and isolation.

typealias HealthCacheStoring = HealthCacheStore
