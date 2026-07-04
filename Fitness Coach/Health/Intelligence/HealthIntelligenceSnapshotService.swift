//
//  HealthIntelligenceSnapshotService.swift
//  Fitness Coach
//
//  Forma — Composes and caches Health Intelligence snapshots without UI coupling.
//
//  Uses an actor for in-flight task coalescing so concurrent tab loads share one compose.
//

import Foundation

protocol HealthIntelligenceSnapshotServing: Sendable {
    func refreshTodaySnapshot(calendar: Calendar) async
    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot?
    func loadSnapshot(
        for date: Date,
        mode: HealthIntelligenceComposeMode,
        calendar: Calendar
    ) async -> HealthIntelligenceSnapshot?
    func invalidateSnapshots(from startDay: Date, through endDay: Date, calendar: Calendar) async
}

extension HealthIntelligenceSnapshotServing {
    func loadSnapshot(
        for date: Date,
        mode: HealthIntelligenceComposeMode = .today,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot? {
        if mode == .today {
            return await loadTodaySnapshot(for: date, calendar: calendar)
        }
        return nil
    }

    func invalidateSnapshots(
        from startDay: Date,
        through endDay: Date,
        calendar: Calendar = .current
    ) async {}
}

struct NoOpHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing {
    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        nil
    }
}

actor HealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing {

    private let engine: any HealthIntelligenceEngineing
    private let cacheStore: any HealthCacheStore
    private let enginesEnabled: Bool
    private var inFlightLoads: [Date: Task<HealthIntelligenceSnapshot, Never>] = [:]

    init(
        engine: any HealthIntelligenceEngineing,
        cacheStore: any HealthCacheStore,
        enginesEnabled: Bool = HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled
    ) {
        self.engine = engine
        self.cacheStore = cacheStore
        self.enginesEnabled = enginesEnabled
    }

    func refreshTodaySnapshot(calendar: Calendar = .current) async {
        guard enginesEnabled else { return }

        let today = calendar.startOfDay(for: Date())
        await invalidateSnapshots(from: today, through: today, calendar: calendar)

        let snapshot = await loadTodaySnapshot(for: today, calendar: calendar)
        guard let snapshot else { return }

        let report = HealthIntelligenceSnapshotVerifier.buildReport(
            snapshot: snapshot,
            trainingLoad: nil,
            calendar: calendar
        )
        HealthIntelligenceSnapshotVerifier.log(report)
    }

    func loadTodaySnapshot(
        for date: Date,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot? {
        await loadSnapshot(for: date, mode: .today, calendar: calendar)
    }

    func loadSnapshot(
        for date: Date,
        mode: HealthIntelligenceComposeMode,
        calendar: Calendar = .current
    ) async -> HealthIntelligenceSnapshot? {
        guard enginesEnabled else { return nil }

        let day = calendar.startOfDay(for: date)
        let dayKey = HealthIntelligenceSnapshotLogger.dayKey(for: day, calendar: calendar)
        let modeLabel = mode.logLabel
        let now = Date()

        HealthIntelligenceSnapshotLogger.loadStarted(
            dayKey: dayKey,
            mode: modeLabel,
            source: "loadSnapshot"
        )

        if let entry = cacheStore.intelligenceSnapshotEntry(for: day, calendar: calendar),
           HealthCachePolicy.isIntelligenceSnapshotFresh(
               cachedAt: entry.cachedAt,
               for: day,
               calendar: calendar,
               now: now
           ) {
            let ageSeconds = max(0, Int(now.timeIntervalSince(entry.cachedAt)))
            HealthIntelligenceSnapshotLogger.cacheHit(
                dayKey: dayKey,
                mode: modeLabel,
                ageSeconds: ageSeconds
            )
            return entry.snapshot
        }

        if cacheStore.intelligenceSnapshotEntry(for: day, calendar: calendar) != nil {
            HealthIntelligenceSnapshotLogger.cacheMiss(
                dayKey: dayKey,
                mode: modeLabel,
                reason: "stale"
            )
        } else {
            HealthIntelligenceSnapshotLogger.cacheMiss(
                dayKey: dayKey,
                mode: modeLabel,
                reason: "not_cached"
            )
        }

        if let existing = inFlightLoads[day] {
            HealthIntelligenceSnapshotLogger.coalescedInFlight(dayKey: dayKey, mode: modeLabel)
            return await existing.value
        }

        let engine = self.engine
        let cacheStore = self.cacheStore
        let composeStartedAt = Date()
        HealthIntelligenceSnapshotLogger.compositionStarted(dayKey: dayKey, mode: modeLabel)

        let task = Task {
            let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: mode)
            cacheStore.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)
            return snapshot
        }

        inFlightLoads[day] = task
        let snapshot = await task.value
        inFlightLoads.removeValue(forKey: day)

        let durationMs = Int(Date().timeIntervalSince(composeStartedAt) * 1_000)
        HealthIntelligenceSnapshotLogger.compositionCompleted(
            dayKey: dayKey,
            mode: modeLabel,
            durationMs: durationMs
        )

        return snapshot
    }

    func invalidateSnapshots(
        from startDay: Date,
        through endDay: Date,
        calendar: Calendar = .current
    ) async {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)

        let keysToCancel = inFlightLoads.keys.filter { $0 >= start && $0 <= end }
        for day in keysToCancel {
            inFlightLoads[day]?.cancel()
            inFlightLoads.removeValue(forKey: day)
        }

        cacheStore.removeIntelligenceSnapshots(from: start, through: end, calendar: calendar)

        let dayCount = Self.inclusiveDayCount(from: start, through: end, calendar: calendar)
        HealthIntelligenceSnapshotLogger.invalidated(
            dayCount: dayCount,
            cancelledInFlightCount: keysToCancel.count
        )
    }

    private static func inclusiveDayCount(
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> Int {
        guard start <= end else { return 0 }
        var count = 0
        var cursor = start
        while cursor <= end {
            count += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }
}
