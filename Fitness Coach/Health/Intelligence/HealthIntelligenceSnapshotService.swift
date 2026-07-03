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
    private var inFlightLoads: [Date: Task<HealthIntelligenceSnapshot?, Never>] = [:]

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
        let now = Date()

        if let entry = cacheStore.intelligenceSnapshotEntry(for: day, calendar: calendar),
           HealthCachePolicy.isIntelligenceSnapshotFresh(
               cachedAt: entry.cachedAt,
               for: day,
               calendar: calendar,
               now: now
           ) {
            return entry.snapshot
        }

        if let existing = inFlightLoads[day] {
            return await existing.value
        }

        let engine = self.engine
        let cacheStore = self.cacheStore
        let task = Task {
            let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: mode)
            cacheStore.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)
            return snapshot
        }

        inFlightLoads[day] = task
        let snapshot = await task.value
        inFlightLoads.removeValue(forKey: day)
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
    }
}
